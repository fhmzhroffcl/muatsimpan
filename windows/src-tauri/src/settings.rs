//! Persistent settings — port of Sources/Musim/Models/AppSettings.swift.
//! Backed by a JSON file in %APPDATA%/Musim instead of macOS UserDefaults.

use crate::models::{ContainerOption, MediaType, QualityPreset};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum AppLanguage {
    Malay,
    English,
}

impl Default for AppLanguage {
    fn default() -> Self {
        AppLanguage::Malay
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum AppAppearance {
    System,
    Light,
    Dark,
}

impl Default for AppAppearance {
    fn default() -> Self {
        AppAppearance::Dark
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum HistoryLogFrequency {
    Never,
    Daily,
    Weekly,
    Monthly,
}

impl Default for HistoryLogFrequency {
    fn default() -> Self {
        HistoryLogFrequency::Weekly
    }
}

/// Browsers yt-dlp can pull cookies from on Windows (no Safari here).
pub const BROWSERS: &[&str] = &[
    "none", "auto", "chrome", "edge", "firefox", "brave", "opera", "vivaldi", "chromium",
];

pub const DEFAULT_PLATFORM_FOLDERS: &[&str] = &["YouTube", "TikTok", "Facebook", "Instagram"];
pub const DEFAULT_TEMPLATE: &str = "%(title)s.%(ext)s";

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AppSettings {
    #[serde(default)]
    pub onboarding_completed: bool,
    #[serde(default)]
    pub user_name: String,
    #[serde(default = "default_download_path")]
    pub download_path: String,
    #[serde(default = "default_concurrency")]
    pub max_concurrent_downloads: usize,
    #[serde(default = "default_browser")]
    pub browser_for_cookies: String,
    #[serde(default)]
    pub proxy: String,
    #[serde(default = "default_template")]
    pub filename_template: String,
    #[serde(default = "yes")]
    pub auto_naming: bool,
    #[serde(default)]
    pub one_click_type: MediaType,
    #[serde(default)]
    pub one_click_quality: QualityPreset,
    #[serde(default)]
    pub container: ContainerOption,
    #[serde(default)]
    pub embed_subs: bool,
    #[serde(default = "yes")]
    pub embed_thumbnail: bool,
    #[serde(default = "yes")]
    pub embed_metadata: bool,
    #[serde(default)]
    pub embed_chapters: bool,
    #[serde(default = "yes")]
    pub notify_on_complete: bool,
    #[serde(default)]
    pub channel_subfolders: bool,
    #[serde(default = "yes")]
    pub organize_by_platform: bool,
    #[serde(default)]
    pub language: AppLanguage,
    #[serde(default)]
    pub appearance: AppAppearance,
    #[serde(default = "default_accent")]
    pub accent: String,
    #[serde(default = "default_pattern")]
    pub pattern: String,
    #[serde(default = "yes")]
    pub auto_update_engine: bool,
    #[serde(default)]
    pub history_log: HistoryLogFrequency,
    // Advanced naming
    #[serde(default)]
    pub advanced_naming: bool,
    #[serde(default)]
    pub name_prefix: String,
    #[serde(default)]
    pub name_suffix: String,
    #[serde(default = "default_separator")]
    pub name_separator: String,
    #[serde(default = "default_name_date")]
    pub name_date: String, // "none" | "%Y%m%d" | "%Y-%m-%d"
    #[serde(default)]
    pub name_counter: bool,
}

fn yes() -> bool {
    true
}
fn default_concurrency() -> usize {
    3
}
fn default_browser() -> String {
    "none".to_string()
}
fn default_template() -> String {
    DEFAULT_TEMPLATE.to_string()
}
fn default_accent() -> String {
    "sunset".to_string()
}
fn default_pattern() -> String {
    "batik".to_string()
}
fn default_separator() -> String {
    " - ".to_string()
}
fn default_name_date() -> String {
    "none".to_string()
}

/// %USERPROFILE%\Downloads\Musim
pub fn default_download_path() -> String {
    let downloads = dirs::download_dir()
        .or_else(|| dirs::home_dir().map(|h| h.join("Downloads")))
        .unwrap_or_else(|| PathBuf::from("."));
    downloads.join("Musim").to_string_lossy().to_string()
}

impl Default for AppSettings {
    fn default() -> Self {
        AppSettings {
            onboarding_completed: false,
            user_name: String::new(),
            download_path: default_download_path(),
            max_concurrent_downloads: 3,
            browser_for_cookies: "none".to_string(),
            proxy: String::new(),
            filename_template: DEFAULT_TEMPLATE.to_string(),
            auto_naming: true,
            one_click_type: MediaType::Video,
            one_click_quality: QualityPreset::Best,
            container: ContainerOption::Auto,
            embed_subs: false,
            embed_thumbnail: true,
            embed_metadata: true,
            embed_chapters: false,
            notify_on_complete: true,
            channel_subfolders: false,
            organize_by_platform: true,
            language: AppLanguage::Malay,
            appearance: AppAppearance::Dark,
            accent: "sunset".to_string(),
            pattern: "batik".to_string(),
            auto_update_engine: true,
            history_log: HistoryLogFrequency::Weekly,
            advanced_naming: false,
            name_prefix: String::new(),
            name_suffix: String::new(),
            name_separator: " - ".to_string(),
            name_date: "none".to_string(),
            name_counter: false,
        }
    }
}

impl AppSettings {
    pub fn uses_cookies(&self) -> bool {
        self.browser_for_cookies != "none"
    }

    /// "auto" resolves to the detected default browser.
    pub fn resolved_cookie_browser(&self) -> String {
        if self.browser_for_cookies == "auto" {
            default_system_browser()
        } else {
            self.browser_for_cookies.clone()
        }
    }

    /// The yt-dlp output template actually used for downloads.
    pub fn effective_template(&self) -> String {
        if !self.auto_naming {
            return "%(id)s.%(ext)s".to_string();
        }
        if !self.advanced_naming {
            return self.filename_template.clone();
        }
        let mut parts: Vec<String> = Vec::new();
        if !self.name_prefix.is_empty() {
            parts.push(self.name_prefix.clone());
        }
        parts.push("%(title)s".to_string());
        if self.name_date != "none" {
            parts.push(format!("%(upload_date>{})s", self.name_date));
        }
        if self.name_counter {
            parts.push("%(autonumber)03d".to_string());
        }
        if !self.name_suffix.is_empty() {
            parts.push(self.name_suffix.clone());
        }
        format!("{}.%(ext)s", parts.join(&self.name_separator))
    }

    pub fn ensure_download_directory(&self) {
        let root = PathBuf::from(&self.download_path);
        let _ = std::fs::create_dir_all(&root);
        for folder in DEFAULT_PLATFORM_FOLDERS {
            let _ = std::fs::create_dir_all(root.join(folder));
        }
    }
}

/// Best-effort default-browser detection on Windows via the registry
/// UserChoice ProgId. Falls back to "edge".
pub fn default_system_browser() -> String {
    #[cfg(windows)]
    {
        use std::process::Command;
        // Query the https UserChoice ProgId.
        let out = Command::new("reg")
            .args([
                "query",
                r"HKCU\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice",
                "/v",
                "ProgId",
            ])
            .output();
        if let Ok(out) = out {
            let s = String::from_utf8_lossy(&out.stdout).to_lowercase();
            if s.contains("chrome") {
                return "chrome".to_string();
            }
            if s.contains("firefox") {
                return "firefox".to_string();
            }
            if s.contains("brave") {
                return "brave".to_string();
            }
            if s.contains("opera") {
                return "opera".to_string();
            }
            if s.contains("vivaldi") {
                return "vivaldi".to_string();
            }
            if s.contains("edge") || s.contains("msedge") {
                return "edge".to_string();
            }
        }
    }
    "edge".to_string()
}
