//! Shared application state, managed by Tauri.

use crate::download::DownloadManager;
use crate::library::LibraryStore;
use crate::settings::AppSettings;
use crate::ytdlp::Engine;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

pub struct AppState {
    pub settings: Mutex<AppSettings>,
    pub settings_path: PathBuf,
    pub engine: Engine,
    pub downloads: Arc<DownloadManager>,
    pub library: Arc<LibraryStore>,
}

impl AppState {
    pub fn persist_settings(&self) {
        let settings = self.settings.lock().unwrap();
        if let Ok(data) = serde_json::to_vec_pretty(&*settings) {
            let _ = std::fs::write(&self.settings_path, data);
        }
    }
}
