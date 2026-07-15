//! Library store — port of Sources/Musim/Engine/LibraryStore.swift.
//! A live view over the downloads folder; renames/moves happen on the real
//! filesystem (Explorer reflects them). Sticky notes and canvas positions live
//! in sidecar JSON keyed by path-relative-to-root. Clip/edit export uses ffmpeg
//! (the macOS build used AVFoundation, unavailable on Windows).

use crate::models::{LibraryEntry, StickyNote};
use crate::settings::AppSettings;
use crate::ytdlp::Engine;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::sync::Mutex;
use tokio::process::Command;

pub const MAX_NOTES_PER_ITEM: usize = 5;
const MEDIA_EXTS: &[&str] = &[
    "mp4", "mkv", "webm", "mov", "m4v", "avi", "mp3", "m4a", "wav", "flac", "opus", "ogg",
];
const AUDIO_EXTS: &[&str] = &["mp3", "m4a", "wav", "flac", "opus", "ogg"];

fn is_media(ext: &str) -> bool {
    MEDIA_EXTS.contains(&ext.to_lowercase().as_str())
}

pub struct LibraryStore {
    notes: Mutex<HashMap<String, Vec<StickyNote>>>,
    positions: Mutex<HashMap<String, [f64; 2]>>,
    support_dir: PathBuf,
}

impl LibraryStore {
    pub fn new(support_dir: PathBuf) -> Self {
        let notes = load_json(&support_dir.join("notes.json")).unwrap_or_default();
        let positions = load_json(&support_dir.join("positions.json")).unwrap_or_default();
        LibraryStore {
            notes: Mutex::new(notes),
            positions: Mutex::new(positions),
            support_dir,
        }
    }

    fn root(settings: &AppSettings) -> PathBuf {
        PathBuf::from(&settings.download_path)
    }

    fn rel_path(root: &Path, p: &Path) -> String {
        p.strip_prefix(root)
            .map(|r| r.to_string_lossy().replace('\\', "/"))
            .unwrap_or_else(|_| p.to_string_lossy().to_string())
    }

    fn notes_path(&self) -> PathBuf {
        self.support_dir.join("notes.json")
    }
    fn positions_path(&self) -> PathBuf {
        self.support_dir.join("positions.json")
    }

    // MARK: Browse

    pub fn browse(&self, settings: &AppSettings, folder: Option<&str>) -> BrowseResult {
        settings.ensure_download_directory();
        let root = Self::root(settings);
        let mut current = folder
            .map(PathBuf::from)
            .unwrap_or_else(|| root.clone());
        if !current.starts_with(&root) {
            current = root.clone();
        }
        let _ = std::fs::create_dir_all(&current);

        let mut entries: Vec<LibraryEntry> = Vec::new();
        if let Ok(rd) = std::fs::read_dir(&current) {
            for e in rd.flatten() {
                let path = e.path();
                let name = e.file_name().to_string_lossy().to_string();
                if name.starts_with('.') {
                    continue;
                }
                let meta = match e.metadata() {
                    Ok(m) => m,
                    Err(_) => continue,
                };
                let is_folder = meta.is_dir();
                let ext = path
                    .extension()
                    .map(|s| s.to_string_lossy().to_lowercase())
                    .unwrap_or_default();
                if !is_folder && !is_media(&ext) && !ext.is_empty() {
                    continue;
                }
                entries.push(LibraryEntry {
                    id: path.to_string_lossy().to_string(),
                    path: path.to_string_lossy().to_string(),
                    name,
                    is_folder,
                    size: meta.len() as i64,
                    modified: modified_millis(&meta),
                    is_media: !is_folder && is_media(&ext),
                });
            }
        }
        entries.sort_by(|a, b| {
            if a.is_folder != b.is_folder {
                b.is_folder.cmp(&a.is_folder)
            } else {
                b.modified.cmp(&a.modified)
            }
        });

        BrowseResult {
            entries,
            current_folder: current.to_string_lossy().to_string(),
            root: root.to_string_lossy().to_string(),
            is_at_root: current == root,
        }
    }

    pub fn all_media(&self, settings: &AppSettings) -> Vec<LibraryEntry> {
        let root = Self::root(settings);
        let mut out: Vec<LibraryEntry> = Vec::new();
        for e in walkdir::WalkDir::new(&root)
            .into_iter()
            .filter_map(|e| e.ok())
            .filter(|e| e.file_type().is_file())
        {
            let path = e.path();
            let ext = path
                .extension()
                .map(|s| s.to_string_lossy().to_lowercase())
                .unwrap_or_default();
            if !is_media(&ext) {
                continue;
            }
            let meta = match e.metadata() {
                Ok(m) => m,
                Err(_) => continue,
            };
            out.push(LibraryEntry {
                id: path.to_string_lossy().to_string(),
                path: path.to_string_lossy().to_string(),
                name: path.file_name().unwrap_or_default().to_string_lossy().to_string(),
                is_folder: false,
                size: meta.len() as i64,
                modified: modified_millis(&meta),
                is_media: true,
            });
        }
        out.sort_by(|a, b| b.modified.cmp(&a.modified));
        out
    }

    // MARK: Filesystem ops

    pub fn rename(&self, settings: &AppSettings, path: &str, new_name: &str) -> Result<(), String> {
        let clean = new_name.trim();
        if clean.is_empty() {
            return Err("empty name".into());
        }
        let src = PathBuf::from(path);
        let dest = src.parent().unwrap_or(Path::new(".")).join(clean);
        std::fs::rename(&src, &dest).map_err(|e| e.to_string())?;
        self.move_note(settings, &src, &dest);
        Ok(())
    }

    pub fn new_folder(&self, settings: &AppSettings, parent: Option<&str>, name: &str) -> Result<String, String> {
        let root = Self::root(settings);
        let parent = parent.map(PathBuf::from).unwrap_or(root);
        let base = if name.trim().is_empty() { "New Folder" } else { name.trim() };
        let mut dest = parent.join(base);
        let mut n = 2;
        while dest.exists() {
            dest = parent.join(format!("{base} {n}"));
            n += 1;
        }
        std::fs::create_dir_all(&dest).map_err(|e| e.to_string())?;
        Ok(dest.to_string_lossy().to_string())
    }

    pub fn move_paths(&self, settings: &AppSettings, paths: Vec<String>, into: &str) -> Result<(), String> {
        let folder = PathBuf::from(into);
        if !folder.is_dir() {
            return Err("target is not a folder".into());
        }
        for path in paths {
            let src = PathBuf::from(&path);
            if !src.exists() {
                continue;
            }
            if src == folder || folder.starts_with(&src) {
                continue;
            }
            let name = src.file_name().unwrap_or_default().to_string_lossy().to_string();
            let dest = unique_destination(&folder, &name);
            if std::fs::rename(&src, &dest).is_ok() {
                self.move_note(settings, &src, &dest);
            }
        }
        Ok(())
    }

    pub fn copy(&self, entry_path: &str) -> Result<(), String> {
        let src = PathBuf::from(entry_path);
        let dir = src.parent().unwrap_or(Path::new(".")).to_path_buf();
        let stem = src.file_stem().unwrap_or_default().to_string_lossy().to_string();
        let ext = src.extension().map(|s| s.to_string_lossy().to_string()).unwrap_or_default();
        let mk = |suffix: String| {
            if ext.is_empty() {
                dir.join(suffix)
            } else {
                dir.join(format!("{suffix}.{ext}"))
            }
        };
        let mut dest = mk(format!("{stem} copy"));
        let mut n = 2;
        while dest.exists() {
            dest = mk(format!("{stem} copy {n}"));
            n += 1;
        }
        std::fs::copy(&src, &dest).map_err(|e| e.to_string())?;
        Ok(())
    }

    pub fn trash(&self, settings: &AppSettings, path: &str) -> Result<(), String> {
        trash::delete(path).map_err(|e| e.to_string())?;
        let root = Self::root(settings);
        let key = Self::rel_path(&root, Path::new(path));
        self.notes.lock().unwrap().remove(&key);
        self.save_notes();
        Ok(())
    }

    // MARK: Notes

    pub fn notes_for(&self, settings: &AppSettings, path: &str) -> Vec<StickyNote> {
        let root = Self::root(settings);
        let key = Self::rel_path(&root, Path::new(path));
        self.notes.lock().unwrap().get(&key).cloned().unwrap_or_default()
    }

    pub fn upsert_note(&self, settings: &AppSettings, path: &str, note: StickyNote) {
        let root = Self::root(settings);
        let key = Self::rel_path(&root, Path::new(path));
        let mut notes = self.notes.lock().unwrap();
        let list = notes.entry(key.clone()).or_default();
        if let Some(existing) = list.iter_mut().find(|n| n.id == note.id) {
            *existing = note;
        } else if list.len() < MAX_NOTES_PER_ITEM {
            list.push(note);
        }
        if list.is_empty() {
            notes.remove(&key);
        }
        drop(notes);
        self.save_notes();
    }

    pub fn remove_note(&self, settings: &AppSettings, path: &str, note_id: &str) {
        let root = Self::root(settings);
        let key = Self::rel_path(&root, Path::new(path));
        let mut notes = self.notes.lock().unwrap();
        if let Some(list) = notes.get_mut(&key) {
            list.retain(|n| n.id != note_id);
            if list.is_empty() {
                notes.remove(&key);
            }
        }
        drop(notes);
        self.save_notes();
    }

    pub fn all_notes(&self, settings: &AppSettings) -> Vec<NoteWithEntry> {
        let root = Self::root(settings);
        let notes = self.notes.lock().unwrap();
        let mut out: Vec<NoteWithEntry> = Vec::new();
        for (key, list) in notes.iter() {
            let path = root.join(key);
            let Ok(meta) = std::fs::metadata(&path) else {
                continue;
            };
            let entry = LibraryEntry {
                id: path.to_string_lossy().to_string(),
                path: path.to_string_lossy().to_string(),
                name: path.file_name().unwrap_or_default().to_string_lossy().to_string(),
                is_folder: meta.is_dir(),
                size: meta.len() as i64,
                modified: modified_millis(&meta),
                is_media: !meta.is_dir()
                    && is_media(&path.extension().map(|s| s.to_string_lossy().to_lowercase()).unwrap_or_default()),
            };
            for n in list {
                out.push(NoteWithEntry {
                    entry: entry.clone(),
                    note: n.clone(),
                });
            }
        }
        out.sort_by(|a, b| a.entry.name.to_lowercase().cmp(&b.entry.name.to_lowercase()));
        out
    }

    fn save_notes(&self) {
        if let Ok(data) = serde_json::to_vec(&*self.notes.lock().unwrap()) {
            let _ = std::fs::write(self.notes_path(), data);
        }
    }

    // MARK: Positions

    pub fn positions(&self) -> HashMap<String, [f64; 2]> {
        self.positions.lock().unwrap().clone()
    }

    pub fn set_position(&self, settings: &AppSettings, path: &str, x: f64, y: f64) {
        let root = Self::root(settings);
        let key = Self::rel_path(&root, Path::new(path));
        self.positions.lock().unwrap().insert(key, [x, y]);
        if let Ok(data) = serde_json::to_vec(&*self.positions.lock().unwrap()) {
            let _ = std::fs::write(self.positions_path(), data);
        }
    }

    fn move_note(&self, settings: &AppSettings, from: &Path, to: &Path) {
        let root = Self::root(settings);
        let old = Self::rel_path(&root, from);
        let new = Self::rel_path(&root, to);
        {
            let mut notes = self.notes.lock().unwrap();
            if let Some(n) = notes.remove(&old) {
                notes.insert(new.clone(), n);
            }
        }
        {
            let mut pos = self.positions.lock().unwrap();
            if let Some(p) = pos.remove(&old) {
                pos.insert(new, p);
            }
        }
        self.save_notes();
        if let Ok(data) = serde_json::to_vec(&*self.positions.lock().unwrap()) {
            let _ = std::fs::write(self.positions_path(), data);
        }
    }
}

// MARK: Clip / edit export (ffmpeg)

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EditOptions {
    pub start: f64,
    pub end: f64,
    #[serde(default = "one")]
    pub speed: f64,
    #[serde(default)]
    pub aspect: String, // "original" | "1:1" | "9:16" | "16:9"
    #[serde(default)]
    pub max_height: Option<i64>,
    #[serde(default = "half")]
    pub crop_x: f64,
    #[serde(default = "half")]
    pub crop_y: f64,
}

fn one() -> f64 {
    1.0
}
fn half() -> f64 {
    0.5
}

fn aspect_ratio(a: &str) -> Option<f64> {
    match a {
        "1:1" => Some(1.0),
        "9:16" => Some(9.0 / 16.0),
        "16:9" => Some(16.0 / 9.0),
        _ => None,
    }
}

fn unique_output(src: &Path, suffix: &str, ext: &str) -> PathBuf {
    let dir = src.parent().unwrap_or(Path::new(".")).to_path_buf();
    let stem = src.file_stem().unwrap_or_default().to_string_lossy().to_string();
    let mut out = dir.join(format!("{stem} {suffix}.{ext}"));
    let mut n = 2;
    while out.exists() {
        out = dir.join(format!("{stem} {suffix} {n}.{ext}"));
        n += 1;
    }
    out
}

/// Quick trim — port of exportClip (was AVFoundation, now a clean ffmpeg re-encode).
pub async fn export_clip(engine: &Engine, path: &str, start: f64, end: f64) -> Result<String, String> {
    let ffmpeg = engine.ffmpeg_path().ok_or("FFmpeg is not available")?;
    let src = PathBuf::from(path);
    let ext = src.extension().map(|s| s.to_string_lossy().to_lowercase()).unwrap_or_default();
    let is_audio = AUDIO_EXTS.contains(&ext.as_str());
    let out_ext = if is_audio { "m4a" } else { "mp4" };
    let out = unique_output(&src, "Clip", out_ext);
    let dur = (end - start).max(0.1);

    let mut args: Vec<String> = vec![
        "-hide_banner".into(),
        "-loglevel".into(),
        "error".into(),
        "-y".into(),
        "-ss".into(),
        format!("{start:.3}"),
        "-i".into(),
        path.to_string(),
        "-t".into(),
        format!("{dur:.3}"),
    ];
    if is_audio {
        args.extend(["-c:a".into(), "aac".into(), "-b:a".into(), "192k".into()]);
    } else {
        args.extend([
            "-map".into(), "0:v:0".into(), "-map".into(), "0:a?".into(),
            "-c:v".into(), "libx264".into(), "-crf".into(), "18".into(),
            "-preset".into(), "medium".into(), "-pix_fmt".into(), "yuv420p".into(),
            "-c:a".into(), "aac".into(), "-b:a".into(), "192k".into(),
            "-movflags".into(), "+faststart".into(),
        ]);
    }
    args.push(out.to_string_lossy().to_string());

    run_ffmpeg(&ffmpeg, &args).await?;
    Ok(out.to_string_lossy().to_string())
}

/// Full edit export (trim + speed + aspect + resolution) — port of exportEdit.
pub async fn export_edit(engine: &Engine, path: &str, options: EditOptions) -> Result<String, String> {
    let ffmpeg = engine.ffmpeg_path().ok_or("FFmpeg is not available")?;
    let src = PathBuf::from(path);
    let out = unique_output(&src, "Edit", "mp4");
    let clip_duration = (options.end - options.start).max(0.1);

    let mut video_filters: Vec<String> = vec![format!("setpts=PTS/{}", options.speed)];
    if let Some(ratio) = aspect_ratio(&options.aspect) {
        let crop = format!(
            "crop=if(gt(iw/ih\\,{r})\\,ih*{r}\\,iw):if(gt(iw/ih\\,{r})\\,ih\\,iw/{r}):(iw-ow)*{cx}:(ih-oh)*{cy}",
            r = ratio,
            cx = options.crop_x,
            cy = options.crop_y
        );
        video_filters.push(crop);
    }
    if let Some(h) = options.max_height {
        video_filters.push(format!("scale=-2:{h}"));
    }

    let mut args: Vec<String> = vec![
        "-hide_banner".into(), "-loglevel".into(), "error".into(), "-y".into(),
        "-ss".into(), format!("{:.3}", options.start), "-i".into(), path.to_string(),
        "-t".into(), format!("{clip_duration:.3}"),
        "-map".into(), "0:v:0".into(), "-map".into(), "0:a?".into(),
        "-vf".into(), video_filters.join(","),
        "-c:v".into(), "libx264".into(), "-crf".into(), "18".into(),
        "-preset".into(), "medium".into(), "-pix_fmt".into(), "yuv420p".into(),
    ];
    if (options.speed - 1.0).abs() > f64::EPSILON {
        args.extend(["-af".into(), format!("atempo={}", options.speed)]);
    }
    args.extend([
        "-c:a".into(), "aac".into(), "-b:a".into(), "192k".into(),
        "-movflags".into(), "+faststart".into(),
        out.to_string_lossy().to_string(),
    ]);

    run_ffmpeg(&ffmpeg, &args).await?;
    Ok(out.to_string_lossy().to_string())
}

async fn run_ffmpeg(ffmpeg: &str, args: &[String]) -> Result<(), String> {
    let mut cmd = Command::new(ffmpeg);
    cmd.args(args).stdout(Stdio::null()).stderr(Stdio::piped());
    #[cfg(windows)]
    cmd.creation_flags(0x0800_0000);
    let output = cmd.output().await.map_err(|e| e.to_string())?;
    if output.status.success() {
        Ok(())
    } else {
        let err = String::from_utf8_lossy(&output.stderr).trim().to_string();
        Err(if err.is_empty() { "Export failed".into() } else { err })
    }
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct BrowseResult {
    pub entries: Vec<LibraryEntry>,
    pub current_folder: String,
    pub root: String,
    pub is_at_root: bool,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct NoteWithEntry {
    pub entry: LibraryEntry,
    pub note: StickyNote,
}

fn unique_destination(folder: &Path, filename: &str) -> PathBuf {
    let original = folder.join(filename);
    if !original.exists() {
        return original;
    }
    let src = Path::new(filename);
    let base = src.file_stem().unwrap_or_default().to_string_lossy().to_string();
    let ext = src.extension().map(|s| s.to_string_lossy().to_string()).unwrap_or_default();
    let mut n = 2;
    loop {
        let name = if ext.is_empty() {
            format!("{base} {n}")
        } else {
            format!("{base} {n}.{ext}")
        };
        let candidate = folder.join(name);
        if !candidate.exists() {
            return candidate;
        }
        n += 1;
    }
}

fn modified_millis(meta: &std::fs::Metadata) -> i64 {
    meta.modified()
        .ok()
        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

fn load_json<T: serde::de::DeserializeOwned>(path: &Path) -> Option<T> {
    std::fs::read(path).ok().and_then(|d| serde_json::from_slice(&d).ok())
}
