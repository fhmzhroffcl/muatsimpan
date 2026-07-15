//! Download queue + history — port of Sources/Musim/Engine/DownloadManager.swift.
//! Runs yt-dlp processes with bounded concurrency, parses live progress from the
//! MUSIM| progress template, persists history, and pushes `downloads-updated`
//! events to the front-end.

use crate::models::{DownloadItem, DownloadStatus, MediaType, Platform};
use crate::state::AppState;
use crate::ytdlp::{build_download_args, DownloadArgsInput};
use std::collections::HashMap;
use std::path::PathBuf;
use std::process::Stdio;
use std::sync::Mutex;
use tauri::{AppHandle, Emitter, Manager};
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;
use tokio_util::sync::CancellationToken;

pub struct DownloadManager {
    items: Mutex<Vec<DownloadItem>>,
    cancels: Mutex<HashMap<String, CancellationToken>>,
    history_path: PathBuf,
    support_dir: PathBuf,
}

impl DownloadManager {
    pub fn new(support_dir: PathBuf) -> Self {
        let history_path = support_dir.join("history.json");
        let mut items = load(&history_path);
        // Anything left mid-download from a previous run is stale.
        for it in items.iter_mut() {
            if matches!(
                it.status,
                DownloadStatus::Pending | DownloadStatus::Downloading | DownloadStatus::Processing
            ) {
                it.status = DownloadStatus::Cancelled;
            }
        }
        DownloadManager {
            items: Mutex::new(items),
            cancels: Mutex::new(HashMap::new()),
            history_path,
            support_dir,
        }
    }

    pub fn snapshot(&self) -> Vec<DownloadItem> {
        self.items.lock().unwrap().clone()
    }

    fn emit(&self, app: &AppHandle) {
        let _ = app.emit("downloads-updated", self.snapshot());
    }

    fn update<F: FnOnce(&mut DownloadItem)>(&self, id: &str, f: F) {
        let mut items = self.items.lock().unwrap();
        if let Some(it) = items.iter_mut().find(|i| i.id == id) {
            f(it);
        }
    }

    fn save(&self) {
        let mut to_save = self.snapshot();
        for it in to_save.iter_mut() {
            if it.log.len() > 2000 {
                it.log = it.log.chars().rev().take(2000).collect::<String>().chars().rev().collect();
            }
        }
        if let Ok(data) = serde_json::to_vec_pretty(&to_save) {
            let _ = std::fs::write(&self.history_path, data);
        }
    }

    // MARK: Queue API

    pub fn enqueue_urls(&self, app: &AppHandle, urls: Vec<String>, media_type: Option<MediaType>) {
        let state = app.state::<AppState>();
        let settings = state.settings.lock().unwrap().clone();
        {
            let mut items = self.items.lock().unwrap();
            for url in urls {
                let mut item = DownloadItem::new(
                    url.clone(),
                    url.clone(),
                    media_type.unwrap_or(settings.one_click_type),
                );
                item.platform = Platform::detect(&url);
                item.quality = settings.one_click_quality;
                item.container = settings.container;
                items.insert(0, item.clone());
            }
        }
        // Kick off metadata fetches for freshly-added pending items.
        let pending_ids: Vec<String> = self
            .snapshot()
            .into_iter()
            .filter(|i| i.status == DownloadStatus::Pending && i.title == i.url)
            .map(|i| i.id)
            .collect();
        self.emit(app);
        for id in pending_ids {
            self.fetch_info(app, &id);
        }
        self.pump(app);
    }

    pub fn enqueue_prepared(&self, app: &AppHandle, prepared: Vec<DownloadItem>) {
        {
            let mut items = self.items.lock().unwrap();
            for mut item in prepared {
                item.status = DownloadStatus::Pending;
                item.platform = Platform::detect(&item.url);
                items.insert(0, item);
            }
        }
        self.emit(app);
        self.pump(app);
    }

    pub fn cancel(&self, app: &AppHandle, id: &str) {
        if let Some(token) = self.cancels.lock().unwrap().remove(id) {
            token.cancel();
        }
        self.update(id, |i| i.status = DownloadStatus::Cancelled);
        self.emit(app);
        self.pump(app);
    }

    pub fn retry(&self, app: &AppHandle, id: &str) {
        self.update(id, |i| {
            i.status = DownloadStatus::Pending;
            i.progress = Default::default();
            i.error_message = None;
        });
        self.emit(app);
        self.pump(app);
    }

    pub fn remove(&self, app: &AppHandle, id: &str) {
        if let Some(token) = self.cancels.lock().unwrap().remove(id) {
            token.cancel();
        }
        self.items.lock().unwrap().retain(|i| i.id != id);
        self.save();
        self.emit(app);
    }

    pub fn clear_history(&self, app: &AppHandle) {
        self.items.lock().unwrap().retain(|i| {
            !matches!(
                i.status,
                DownloadStatus::Completed | DownloadStatus::Error | DownloadStatus::Cancelled
            )
        });
        self.save();
        self.emit(app);
    }

    // MARK: Metadata fetch (title/thumbnail before download)

    fn fetch_info(&self, app: &AppHandle, id: &str) {
        let state = app.state::<AppState>();
        let engine = state.engine.clone();
        let settings = state.settings.lock().unwrap().clone();
        let Some(item) = self.snapshot().into_iter().find(|i| i.id == id) else {
            return;
        };
        let Some(bin) = engine.binary_path() else {
            return;
        };
        let args = crate::ytdlp::info_args(&item.url, &settings, &engine);
        let app = app.clone();
        let id = id.to_string();
        tauri::async_runtime::spawn(async move {
            let mut cmd = Command::new(&bin);
            cmd.args(&args).stdout(Stdio::piped()).stderr(Stdio::null());
            no_window(&mut cmd);
            let Ok(output) = cmd.output().await else { return };
            let out = String::from_utf8_lossy(&output.stdout);
            let Ok(json) = serde_json::from_str::<serde_json::Value>(&out) else {
                return;
            };
            let state = app.state::<AppState>();
            let dl = state.downloads.clone();
            let s = |k: &str| json.get(k).and_then(|v| v.as_str()).map(String::from);
            dl.update(&id, |it| {
                if let Some(t) = s("title") {
                    it.title = t;
                }
                it.thumbnail_url = s("thumbnail");
                it.duration = json.get("duration").and_then(|v| v.as_f64());
                it.uploader = s("uploader");
                it.channel = s("channel").or_else(|| s("uploader"));
                it.description_text = s("description");
                it.view_count = json.get("view_count").and_then(|v| v.as_i64());
                it.format_note = s("resolution").or_else(|| s("format_note"));
                it.ext = s("ext");
                it.audio_format = s("acodec");
            });
            dl.emit(&app);
        });
    }

    // MARK: Scheduler

    fn pump(&self, app: &AppHandle) {
        let state = app.state::<AppState>();
        let max = state.settings.lock().unwrap().max_concurrent_downloads;
        let running = self
            .snapshot()
            .iter()
            .filter(|i| matches!(i.status, DownloadStatus::Downloading | DownloadStatus::Processing))
            .count();
        let mut slots = max.saturating_sub(running);
        if slots == 0 {
            self.save();
            return;
        }
        // Oldest-first among pending (mirrors items.reversed() over newest-first list).
        let pending: Vec<String> = self
            .snapshot()
            .into_iter()
            .rev()
            .filter(|i| i.status == DownloadStatus::Pending)
            .map(|i| i.id)
            .collect();
        for id in pending {
            if slots == 0 {
                break;
            }
            self.start(app, &id);
            slots -= 1;
        }
        self.save();
    }

    fn start(&self, app: &AppHandle, id: &str) {
        let state = app.state::<AppState>();
        let engine = state.engine.clone();
        let settings = state.settings.lock().unwrap().clone();
        let Some(item) = self.snapshot().into_iter().find(|i| i.id == id) else {
            return;
        };
        let Some(bin) = engine.binary_path() else {
            self.update(id, |i| {
                i.status = DownloadStatus::Error;
                i.error_message = Some(
                    if matches!(settings.language, crate::settings::AppLanguage::Malay) {
                        "Enjin yt-dlp belum dipasang".into()
                    } else {
                        "yt-dlp is not installed yet".into()
                    },
                );
            });
            self.emit(app);
            return;
        };

        settings.ensure_download_directory();
        self.update(id, |i| i.status = DownloadStatus::Downloading);
        self.emit(app);

        let args = build_download_args(
            &DownloadArgsInput {
                url: &item.url,
                media_type: item.media_type,
                quality: item.quality,
                container: item.container,
                format_selector: item.format_selector.as_deref(),
                platform: item.platform,
            },
            &settings,
            &engine,
        );

        let token = CancellationToken::new();
        self.cancels.lock().unwrap().insert(id.to_string(), token.clone());

        let app = app.clone();
        let id = id.to_string();
        let support_dir = self.support_dir.clone();
        tauri::async_runtime::spawn(async move {
            run_download(app, id, bin, args, token, settings, support_dir).await;
        });
    }
}

/// The actual child-process lifecycle: spawn, stream stdout, honour cancel, finish.
async fn run_download(
    app: AppHandle,
    id: String,
    bin: String,
    args: Vec<String>,
    token: CancellationToken,
    settings: crate::settings::AppSettings,
    support_dir: PathBuf,
) {
    let dl = app.state::<AppState>().downloads.clone();

    let mut cmd = Command::new(&bin);
    cmd.args(&args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    no_window(&mut cmd);

    let mut child = match cmd.spawn() {
        Ok(c) => c,
        Err(e) => {
            dl.update(&id, |i| {
                i.status = DownloadStatus::Error;
                i.error_message = Some(e.to_string());
            });
            dl.cancels.lock().unwrap().remove(&id);
            dl.emit(&app);
            dl.pump(&app);
            return;
        }
    };

    let stdout = child.stdout.take();
    let stderr = child.stderr.take();

    // Drain stderr into the item log in the background.
    if let Some(stderr) = stderr {
        let dl2 = dl.clone();
        let app2 = app.clone();
        let id2 = id.clone();
        tauri::async_runtime::spawn(async move {
            let mut lines = BufReader::new(stderr).lines();
            while let Ok(Some(line)) = lines.next_line().await {
                dl2.update(&id2, |i| i.log.push_str(&format!("{line}\n")));
                dl2.emit(&app2);
            }
        });
    }

    let read_stdout = async {
        if let Some(stdout) = stdout {
            let mut lines = BufReader::new(stdout).lines();
            while let Ok(Some(line)) = lines.next_line().await {
                handle_line(&dl, &app, id.as_str(), &line);
            }
        }
    };

    let cancelled;
    let mut success = false;
    tokio::select! {
        _ = read_stdout => {
            let status = child.wait().await;
            success = status.map(|s| s.success()).unwrap_or(false);
            cancelled = dl.snapshot().iter().any(|i| i.id == id && i.status == DownloadStatus::Cancelled);
        }
        _ = token.cancelled() => {
            let _ = child.start_kill();
            let _ = child.wait().await;
            cancelled = true;
        }
    }

    dl.cancels.lock().unwrap().remove(&id);

    if cancelled {
        dl.emit(&app);
        dl.pump(&app);
        return;
    }

    finish(&dl, &app, &id, &settings, &support_dir, success);
}

fn handle_line(dl: &DownloadManager, app: &AppHandle, id: &str, line: &str) {
    if let Some(rest) = line.strip_prefix("MUSIM|") {
        let parts: Vec<&str> = rest.split('|').collect();
        if parts.len() >= 5 {
            let percent = parts[0]
                .replace('%', "")
                .trim()
                .parse::<f64>()
                .unwrap_or(0.0);
            dl.update(id, |i| {
                i.status = DownloadStatus::Downloading;
                i.progress.percent = percent;
                i.progress.speed = Some(parts[1].trim().to_string());
                i.progress.eta = Some(parts[2].trim().to_string());
                i.progress.downloaded = Some(parts[3].trim().to_string());
                i.progress.total = Some(parts[4].trim().to_string());
            });
            dl.emit(app);
        }
    } else if let Some(path) = line.strip_prefix("MUSIMFILE|") {
        let path = path.to_string();
        dl.update(id, |i| i.saved_file_path = Some(path));
    } else if line.contains("[Merger]") || line.contains("[ExtractAudio]") || line.contains("[EmbedThumbnail]")
    {
        let l = line.to_string();
        dl.update(id, |i| {
            i.status = DownloadStatus::Processing;
            i.log.push_str(&format!("{l}\n"));
        });
        dl.emit(app);
    } else {
        let l = line.to_string();
        dl.update(id, |i| i.log.push_str(&format!("{l}\n")));
    }
}

fn finish(
    dl: &DownloadManager,
    app: &AppHandle,
    id: &str,
    settings: &crate::settings::AppSettings,
    support_dir: &PathBuf,
    succeeded: bool,
) {
    let Some(item) = dl.snapshot().into_iter().find(|i| i.id == id) else {
        return;
    };

    if succeeded {
        dl.update(id, |i| {
            i.status = DownloadStatus::Completed;
            i.progress.percent = 100.0;
            i.completed_at = Some(crate::models::now_millis());
            if let Some(path) = &i.saved_file_path {
                if let Ok(meta) = std::fs::metadata(path) {
                    i.file_size = Some(meta.len() as i64);
                }
            }
        });
        if let Some(done) = dl.snapshot().into_iter().find(|i| i.id == id) {
            crate::report::log(&done, settings, support_dir);
        }
        let _ = app.emit("library-should-refresh", ());
        if settings.notify_on_complete {
            let malay = matches!(settings.language, crate::settings::AppLanguage::Malay);
            let title = if item.media_type == MediaType::Video {
                if malay { "Video disimpan" } else { "Video saved" }
            } else if malay {
                "Audio disimpan"
            } else {
                "Music saved"
            };
            notify(app, title, &item.title);
        }
    } else {
        dl.update(id, |i| {
            i.status = DownloadStatus::Error;
            let tail: String = i.log.chars().rev().take(400).collect::<String>().chars().rev().collect();
            i.error_message = Some(tail);
        });
        if settings.notify_on_complete {
            let malay = matches!(settings.language, crate::settings::AppLanguage::Malay);
            notify(app, if malay { "Simpanan gagal" } else { "Save failed" }, &item.title);
        }
    }
    dl.emit(app);
    dl.pump(app);
}

fn notify(app: &AppHandle, title: &str, body: &str) {
    use tauri_plugin_notification::NotificationExt;
    let _ = app.notification().builder().title(title).body(body).show();
}

fn no_window(cmd: &mut Command) {
    // tokio::process::Command exposes creation_flags as an inherent method on Windows.
    #[cfg(windows)]
    cmd.creation_flags(0x0800_0000); // CREATE_NO_WINDOW
    let _ = cmd;
}

fn load(path: &PathBuf) -> Vec<DownloadItem> {
    std::fs::read(path)
        .ok()
        .and_then(|data| serde_json::from_slice(&data).ok())
        .unwrap_or_default()
}
