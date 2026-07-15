//! Data models — a faithful port of Sources/Musim/Models/Models.swift.
//! Field names use camelCase so they serialize 1:1 with the TypeScript front-end.

use serde::{Deserialize, Serialize};
use url::Url;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum DownloadStatus {
    Pending,
    Downloading,
    Processing,
    Completed,
    Error,
    Cancelled,
    Paused,
}

impl Default for DownloadStatus {
    fn default() -> Self {
        DownloadStatus::Pending
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum MediaType {
    Video,
    Audio,
}

impl Default for MediaType {
    fn default() -> Self {
        MediaType::Video
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum QualityPreset {
    Best,
    Good,
    Normal,
    Low,
}

impl Default for QualityPreset {
    fn default() -> Self {
        QualityPreset::Best
    }
}

impl QualityPreset {
    /// yt-dlp format selector — identical strings to the macOS build.
    pub fn video_selector(&self) -> &'static str {
        match self {
            QualityPreset::Best => "bestvideo+bestaudio/best",
            QualityPreset::Good => "bestvideo[height<=1080]+bestaudio/best[height<=1080]/best",
            QualityPreset::Normal => "bestvideo[height<=720]+bestaudio/best[height<=720]/best",
            QualityPreset::Low => "bestvideo[height<=480]+bestaudio/best[height<=480]/best",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ContainerOption {
    Auto,
    Mp4,
    Mkv,
    Webm,
    Original,
}

impl Default for ContainerOption {
    fn default() -> Self {
        ContainerOption::Auto
    }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DownloadProgressInfo {
    #[serde(default)]
    pub percent: f64,
    #[serde(default)]
    pub speed: Option<String>,
    #[serde(default)]
    pub eta: Option<String>,
    #[serde(default)]
    pub downloaded: Option<String>,
    #[serde(default)]
    pub total: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DownloadItem {
    pub id: String,
    pub url: String,
    pub title: String,
    #[serde(default)]
    pub thumbnail_url: Option<String>,
    #[serde(default, rename = "type")]
    pub media_type: MediaType,
    #[serde(default)]
    pub status: DownloadStatus,
    #[serde(default)]
    pub progress: DownloadProgressInfo,
    #[serde(default)]
    pub error_message: Option<String>,
    #[serde(default)]
    pub log: String,
    #[serde(default)]
    pub duration: Option<f64>,
    #[serde(default)]
    pub file_size: Option<i64>,
    #[serde(default)]
    pub saved_file_path: Option<String>,
    #[serde(default)]
    pub uploader: Option<String>,
    #[serde(default)]
    pub channel: Option<String>,
    #[serde(default)]
    pub description_text: Option<String>,
    #[serde(default)]
    pub view_count: Option<i64>,
    #[serde(default)]
    pub platform: Platform,
    #[serde(default)]
    pub format_note: Option<String>,
    #[serde(default)]
    pub ext: Option<String>,
    #[serde(default)]
    pub audio_format: Option<String>,
    #[serde(default)]
    pub quality: QualityPreset,
    #[serde(default)]
    pub container: ContainerOption,
    #[serde(default)]
    pub format_selector: Option<String>,
    #[serde(default)]
    pub quality_label: Option<String>,
    #[serde(default)]
    pub estimated_size: Option<i64>,
    /// Epoch milliseconds — replaces Swift's Date.
    #[serde(default)]
    pub created_at: i64,
    #[serde(default)]
    pub completed_at: Option<i64>,
}

impl DownloadItem {
    pub fn new(url: String, title: String, media_type: MediaType) -> Self {
        DownloadItem {
            id: uuid::Uuid::new_v4().to_string(),
            platform: Platform::detect(&url),
            url,
            title,
            thumbnail_url: None,
            media_type,
            status: DownloadStatus::Pending,
            progress: DownloadProgressInfo::default(),
            error_message: None,
            log: String::new(),
            duration: None,
            file_size: None,
            saved_file_path: None,
            uploader: None,
            channel: None,
            description_text: None,
            view_count: None,
            format_note: None,
            ext: None,
            audio_format: None,
            quality: QualityPreset::Best,
            container: ContainerOption::Auto,
            format_selector: None,
            quality_label: None,
            estimated_size: None,
            created_at: now_millis(),
            completed_at: None,
        }
    }
}

pub fn now_millis() -> i64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Platform {
    Youtube,
    Tiktok,
    Instagram,
    Twitter,
    Facebook,
    Bilibili,
    Vimeo,
    Twitch,
    Soundcloud,
    Reddit,
    Dailymotion,
    Generic,
}

impl Default for Platform {
    fn default() -> Self {
        Platform::Generic
    }
}

impl Platform {
    pub fn label(&self) -> &'static str {
        match self {
            Platform::Youtube => "YouTube",
            Platform::Tiktok => "TikTok",
            Platform::Instagram => "Instagram",
            Platform::Twitter => "X / Twitter",
            Platform::Facebook => "Facebook",
            Platform::Bilibili => "Bilibili",
            Platform::Vimeo => "Vimeo",
            Platform::Twitch => "Twitch",
            Platform::Soundcloud => "SoundCloud",
            Platform::Reddit => "Reddit",
            Platform::Dailymotion => "Dailymotion",
            Platform::Generic => "Web",
        }
    }

    pub fn detect(url: &str) -> Platform {
        let u = url.to_lowercase();
        let has = |s: &str| u.contains(s);
        if has("youtube.com") || has("youtu.be") {
            Platform::Youtube
        } else if has("tiktok.com") {
            Platform::Tiktok
        } else if has("instagram.com") {
            Platform::Instagram
        } else if has("twitter.com") || has("x.com") {
            Platform::Twitter
        } else if has("facebook.com") || has("fb.watch") {
            Platform::Facebook
        } else if has("bilibili.com") {
            Platform::Bilibili
        } else if has("vimeo.com") {
            Platform::Vimeo
        } else if has("twitch.tv") {
            Platform::Twitch
        } else if has("soundcloud.com") {
            Platform::Soundcloud
        } else if has("reddit.com") {
            Platform::Reddit
        } else if has("dailymotion.com") {
            Platform::Dailymotion
        } else {
            Platform::Generic
        }
    }

    /// Folder name used when organising downloads by platform.
    pub fn folder_name(&self, url: Option<&str>) -> String {
        match self {
            Platform::Generic => {
                let host = url
                    .and_then(|u| Url::parse(u).ok())
                    .and_then(|p| p.host_str().map(|h| h.replace("www.", "")))
                    .unwrap_or_default();
                if host.is_empty() {
                    return "Lain-lain".to_string();
                }
                let root = host.split('.').next().unwrap_or(&host).to_string();
                root.replace('-', " ")
                    .split_whitespace()
                    .map(|w| {
                        let mut chars = w.chars();
                        match chars.next() {
                            Some(f) => f.to_uppercase().collect::<String>() + chars.as_str(),
                            None => String::new(),
                        }
                    })
                    .collect::<Vec<_>>()
                    .join(" ")
            }
            _ => self.label().replace(" / Twitter", ""),
        }
    }
}

/// Extract all http(s) links from arbitrary pasted text, de-duped, order-preserving.
pub fn extract_links(text: &str) -> Vec<String> {
    // Matches http:// or https:// followed by non-whitespace, trimming common
    // trailing punctuation that isn't part of a URL.
    let mut out: Vec<String> = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for raw in text.split_whitespace() {
        for token in raw.split(|c| c == '\n' || c == '\t') {
            let t = token.trim();
            if t.starts_with("http://") || t.starts_with("https://") {
                let cleaned = t.trim_end_matches(|c| matches!(c, ')' | ']' | '}' | ',' | '.' | '"' | '\'' | '>'));
                if seen.insert(cleaned.to_string()) {
                    out.push(cleaned.to_string());
                }
            }
        }
    }
    out
}

// MARK: - Sticky notes / library entries

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum NoteSize {
    Square,
    Wide,
    Big,
    Tall,
}

impl Default for NoteSize {
    fn default() -> Self {
        NoteSize::Square
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StickyNote {
    pub id: String,
    #[serde(default)]
    pub text: String,
    #[serde(default = "default_note_color")]
    pub color: String,
    #[serde(default)]
    pub size: NoteSize,
    /// HTML rich text (replaces the macOS RTF blob) — optional.
    #[serde(default)]
    pub html: Option<String>,
}

fn default_note_color() -> String {
    "yellow".to_string()
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LibraryEntry {
    pub id: String,
    pub path: String,
    pub name: String,
    pub is_folder: bool,
    pub size: i64,
    /// Epoch milliseconds.
    pub modified: i64,
    pub is_media: bool,
}
