//! Engine layer — port of Sources/Musim/Engine/YtDlp.swift.
//! Locates the bundled yt-dlp/ffmpeg/deno binaries, builds yt-dlp argument
//! lists, probes media metadata, and (fallback) installs yt-dlp.exe.

use crate::settings::AppSettings;
use serde::Serialize;
use std::path::{Path, PathBuf};
use std::process::Stdio;
use tokio::process::Command;

/// Resolved paths for the bundled command-line tools.
#[derive(Clone)]
pub struct Engine {
    /// %APPDATA%\Musim — writable support directory.
    pub support_dir: PathBuf,
    /// Directory holding the bundled binaries (resource dir /binaries).
    pub binaries_dir: PathBuf,
}

impl Engine {
    fn resolve(&self, name: &str) -> Option<String> {
        let candidates = [
            self.binaries_dir.join(name),
            self.support_dir.join(name),
        ];
        candidates
            .into_iter()
            .find(|p| p.exists())
            .map(|p| p.to_string_lossy().to_string())
    }

    pub fn binary_path(&self) -> Option<String> {
        self.resolve("yt-dlp.exe")
    }
    pub fn ffmpeg_path(&self) -> Option<String> {
        self.resolve("ffmpeg.exe")
    }
    pub fn ffprobe_path(&self) -> Option<String> {
        self.resolve("ffprobe.exe")
    }
    pub fn deno_path(&self) -> Option<String> {
        self.resolve("deno.exe")
    }

    /// `--js-runtimes deno:<path>` — lets yt-dlp solve YouTube's JS n-challenge.
    pub fn js_runtime_args(&self) -> Vec<String> {
        match self.deno_path() {
            Some(deno) => vec!["--js-runtimes".to_string(), format!("deno:{deno}")],
            None => vec![],
        }
    }

    /// Directory containing ffmpeg/ffprobe — passed to yt-dlp so post-processing
    /// (merging, thumbnail/metadata embedding) can find both tools.
    pub fn ffmpeg_dir(&self) -> Option<String> {
        self.ffmpeg_path()
            .and_then(|p| Path::new(&p).parent().map(|d| d.to_string_lossy().to_string()))
    }

    pub fn is_ready(&self) -> bool {
        self.binary_path().is_some()
    }

    /// Fallback install — download the official yt-dlp.exe into the support dir.
    pub async fn install_ytdlp(&self) -> Result<(), String> {
        let url = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe";
        let dest = self.support_dir.join("yt-dlp.exe");
        std::fs::create_dir_all(&self.support_dir).map_err(|e| e.to_string())?;
        let bytes = reqwest::get(url)
            .await
            .map_err(|e| e.to_string())?
            .error_for_status()
            .map_err(|_| "Simpanan alat media gagal (ralat HTTP)".to_string())?
            .bytes()
            .await
            .map_err(|e| e.to_string())?;
        std::fs::write(&dest, &bytes).map_err(|e| e.to_string())?;
        Ok(())
    }
}

// MARK: - Media probe types

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProbedFormat {
    pub id: String,
    pub height: Option<i64>,
    pub ext: String,
    pub vcodec: Option<String>,
    pub acodec: Option<String>,
    pub filesize: Option<i64>,
    pub note: Option<String>,
    pub fps: Option<f64>,
}

impl ProbedFormat {
    pub fn is_video(&self) -> bool {
        self.vcodec.as_deref().unwrap_or("none") != "none"
    }
    pub fn is_audio_only(&self) -> bool {
        !self.is_video() && self.acodec.as_deref().unwrap_or("none") != "none"
    }
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MediaProbe {
    pub title: String,
    pub thumbnail: Option<String>,
    pub description: Option<String>,
    pub uploader: Option<String>,
    pub channel: Option<String>,
    pub duration: Option<f64>,
    pub view_count: Option<i64>,
    pub formats: Vec<ProbedFormat>,
    /// Distinct video heights, descending.
    pub heights: Vec<i64>,
}

pub fn height_label(h: i64) -> String {
    match h {
        _ if h >= 4320 => "8K".to_string(),
        _ if h >= 2160 => "4K".to_string(),
        _ if h >= 1440 => "2K".to_string(),
        _ => format!("{h}p"),
    }
}

/// YouTube blocks the default `web` player client without a JS runtime, which
/// breaks extraction. Mirroring VidBee, drop it so extraction stays reliable.
pub fn youtube_safe_args(url: &str) -> Vec<String> {
    let u = url.to_lowercase();
    if u.contains("youtube.com") || u.contains("youtu.be") {
        vec![
            "--extractor-args".to_string(),
            "youtube:player_client=default,-web".to_string(),
        ]
    } else {
        vec![]
    }
}

/// Turns raw yt-dlp stderr into a short, actionable message (bilingual).
pub fn friendly_error(stderr: &str, malay: bool) -> String {
    let lower = stderr.to_lowercase();
    let has = |s: &str| lower.contains(s);
    if has("log in") || has("logged-in") || has("login required") || has("sign in") || has("private") || has("cookies") {
        return if malay {
            "Pautan ini perlukan log masuk. Hidupkan kuki pelayar dalam Tetapan, kemudian cuba lagi.".into()
        } else {
            "This post needs a login. Turn on browser cookies in Settings, then try again.".into()
        };
    }
    if has("not available") || has("removed") || has("unavailable") || has("410") || has("404") {
        return if malay {
            "Video ini tidak tersedia. Mungkin sudah dipadam, dikunci wilayah, atau ada sekatan umur.".into()
        } else {
            "This video is unavailable — it may be removed, region-locked, or age-restricted.".into()
        };
    }
    if has("unsupported url") || has("no video") {
        return if malay {
            "Pautan ini bukan video yang boleh disimpan.".into()
        } else {
            "This link doesn't contain media that can be saved.".into()
        };
    }
    if has("timed out") || has("timeout") || has("network") || has("resolve host") || has("connection") {
        return if malay {
            "Masalah rangkaian. Semak sambungan internet dan cuba lagi.".into()
        } else {
            "Network problem — check your connection and try again.".into()
        };
    }
    if let Some(line) = stderr.lines().find(|l| l.contains("ERROR")) {
        let cleaned = line.replace("ERROR: ", "");
        return cleaned.chars().take(160).collect();
    }
    if malay {
        "Tidak dapat baca maklumat video. Pautan mungkin peribadi atau belum disokong.".into()
    } else {
        "Could not read video info — the link may be private or unsupported.".into()
    }
}

// MARK: - Argument builders (port of ArgsBuilder)

pub struct DownloadArgsInput<'a> {
    pub url: &'a str,
    pub media_type: crate::models::MediaType,
    pub quality: crate::models::QualityPreset,
    pub container: crate::models::ContainerOption,
    pub format_selector: Option<&'a str>,
    pub platform: crate::models::Platform,
}

pub fn build_download_args(
    input: &DownloadArgsInput,
    settings: &AppSettings,
    engine: &Engine,
) -> Vec<String> {
    use crate::models::{ContainerOption, MediaType};
    let mut args: Vec<String> = vec![
        input.url.to_string(),
        "--newline".into(),
        "--no-playlist".into(),
        "--progress-template".into(),
        "download:MUSIM|%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s|%(progress._downloaded_bytes_str)s|%(progress._total_bytes_str)s".into(),
    ];
    args.extend(youtube_safe_args(input.url));
    args.extend(engine.js_runtime_args());

    match input.media_type {
        MediaType::Video => {
            let selector = input
                .format_selector
                .map(|s| s.to_string())
                .unwrap_or_else(|| input.quality.video_selector().to_string());
            args.push("-f".into());
            args.push(selector);
            match input.container {
                ContainerOption::Mp4 => args.extend(["--merge-output-format".into(), "mp4".into()]),
                ContainerOption::Mkv => args.extend(["--merge-output-format".into(), "mkv".into()]),
                ContainerOption::Webm => args.extend(["--merge-output-format".into(), "webm".into()]),
                ContainerOption::Auto => args.extend(["--merge-output-format".into(), "mp4/mkv".into()]),
                ContainerOption::Original => {}
            }
        }
        MediaType::Audio => {
            args.extend([
                "-f".into(),
                "bestaudio/best".into(),
                "-x".into(),
                "--audio-format".into(),
                "mp3".into(),
                "--audio-quality".into(),
                "0".into(),
            ]);
        }
    }

    // Output template (advanced naming composes prefix/date/counter/suffix).
    let mut template = settings.effective_template();
    if settings.channel_subfolders {
        template = format!("%(uploader)s/{template}");
    }
    if settings.organize_by_platform {
        template = format!("{}/{}", input.platform.folder_name(Some(input.url)), template);
    }
    let out_path = Path::new(&settings.download_path).join(&template);
    args.push("-o".into());
    args.push(out_path.to_string_lossy().to_string());

    if settings.auto_naming && settings.advanced_naming && settings.name_counter {
        args.extend(["--autonumber-start".into(), "1".into()]);
    }

    if settings.uses_cookies() {
        args.extend([
            "--cookies-from-browser".into(),
            settings.resolved_cookie_browser(),
        ]);
    }
    if !settings.proxy.is_empty() {
        args.extend(["--proxy".into(), settings.proxy.clone()]);
    }
    if settings.embed_subs && input.media_type == MediaType::Video {
        args.extend([
            "--embed-subs".into(),
            "--sub-langs".into(),
            "en.*,-live_chat".into(),
        ]);
    }
    if settings.embed_thumbnail {
        args.push("--embed-thumbnail".into());
    }
    if settings.embed_metadata {
        args.push("--embed-metadata".into());
    }
    if settings.embed_chapters && input.media_type == MediaType::Video {
        args.push("--embed-chapters".into());
    }
    if let Some(dir) = engine.ffmpeg_dir() {
        args.extend(["--ffmpeg-location".into(), dir]);
    }
    args.extend([
        "--print".into(),
        "after_move:MUSIMFILE|%(filepath)s".into(),
        "--no-simulate".into(),
        "--no-quiet".into(),
    ]);
    args
}

pub fn info_args(url: &str, settings: &AppSettings, engine: &Engine) -> Vec<String> {
    let mut args: Vec<String> = vec![
        url.to_string(),
        "--dump-json".into(),
        "--no-playlist".into(),
        "--no-warnings".into(),
        "--skip-download".into(),
    ];
    args.extend(youtube_safe_args(url));
    args.extend(engine.js_runtime_args());
    if settings.uses_cookies() {
        args.extend([
            "--cookies-from-browser".into(),
            settings.resolved_cookie_browser(),
        ]);
    }
    if !settings.proxy.is_empty() {
        args.extend(["--proxy".into(), settings.proxy.clone()]);
    }
    args
}

// MARK: - Probe execution

fn command(bin: &str) -> Command {
    let mut c = Command::new(bin);
    c.stdout(Stdio::piped()).stderr(Stdio::piped());
    // CREATE_NO_WINDOW — never flash a console window (inherent tokio method).
    #[cfg(windows)]
    c.creation_flags(0x0800_0000);
    c
}

/// Run `yt-dlp --dump-json` and parse metadata + the full format table.
pub async fn probe(url: &str, settings: &AppSettings, engine: &Engine) -> Result<MediaProbe, String> {
    let malay = matches!(settings.language, crate::settings::AppLanguage::Malay);
    let bin = engine
        .binary_path()
        .ok_or_else(|| if malay { "Enjin belum sedia".to_string() } else { "Engine not ready".to_string() })?;

    let mut args: Vec<String> = vec![
        url.to_string(),
        "--dump-json".into(),
        "--no-playlist".into(),
        "--no-warnings".into(),
        "--skip-download".into(),
    ];
    args.extend(youtube_safe_args(url));
    args.extend(engine.js_runtime_args());
    if settings.browser_for_cookies != "none" {
        args.extend([
            "--cookies-from-browser".into(),
            settings.resolved_cookie_browser(),
        ]);
    }
    if !settings.proxy.is_empty() {
        args.extend(["--proxy".into(), settings.proxy.clone()]);
    }

    let output = command(&bin)
        .args(&args)
        .output()
        .await
        .map_err(|e| e.to_string())?;
    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();

    let json: serde_json::Value =
        serde_json::from_str(&stdout).map_err(|_| friendly_error(&stderr, malay))?;

    let formats: Vec<ProbedFormat> = json
        .get("formats")
        .and_then(|f| f.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|f| {
                    let id = f.get("format_id")?.as_str()?.to_string();
                    let size = f
                        .get("filesize")
                        .and_then(|v| v.as_i64())
                        .or_else(|| f.get("filesize_approx").and_then(|v| v.as_i64()));
                    Some(ProbedFormat {
                        id,
                        height: f.get("height").and_then(|v| v.as_i64()),
                        ext: f.get("ext").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                        vcodec: f.get("vcodec").and_then(|v| v.as_str()).map(String::from),
                        acodec: f.get("acodec").and_then(|v| v.as_str()).map(String::from),
                        filesize: size,
                        note: f.get("format_note").and_then(|v| v.as_str()).map(String::from),
                        fps: f.get("fps").and_then(|v| v.as_f64()),
                    })
                })
                .collect()
        })
        .unwrap_or_default();

    let mut heights: Vec<i64> = formats
        .iter()
        .filter(|f| f.is_video())
        .filter_map(|f| f.height)
        .collect();
    heights.sort_unstable();
    heights.dedup();
    heights.reverse();

    let s = |k: &str| json.get(k).and_then(|v| v.as_str()).map(String::from);
    Ok(MediaProbe {
        title: s("title").unwrap_or_else(|| url.to_string()),
        thumbnail: s("thumbnail"),
        description: s("description"),
        uploader: s("uploader"),
        channel: s("channel").or_else(|| s("uploader")),
        duration: json.get("duration").and_then(|v| v.as_f64()),
        view_count: json.get("view_count").and_then(|v| v.as_i64()),
        formats,
        heights,
    })
}

/// Full list of yt-dlp extractors, filtered to plain names.
pub async fn list_extractors(engine: &Engine) -> Vec<String> {
    let Some(bin) = engine.binary_path() else {
        return vec![];
    };
    let Ok(output) = command(&bin).args(["--list-extractors"]).output().await else {
        return vec![];
    };
    String::from_utf8_lossy(&output.stdout)
        .lines()
        .map(|l| l.trim().to_string())
        .filter(|l| !l.is_empty() && !l.starts_with('['))
        .collect()
}
