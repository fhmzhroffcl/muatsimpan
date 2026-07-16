//! Tauri entry point + command surface for the Windows build of Musim.

mod commands;
mod download;
mod library;
mod models;
mod report;
mod settings;
mod state;
mod ytdlp;

use download::DownloadManager;
use library::LibraryStore;
use settings::AppSettings;
use state::AppState;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use tauri::Manager;
use ytdlp::Engine;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_notification::init())
        .setup(|app| {
            // %APPDATA%\Musim — writable support dir (history, notes, reports).
            let support_dir = dirs::data_dir()
                .unwrap_or_else(|| PathBuf::from("."))
                .join("Musim");
            std::fs::create_dir_all(&support_dir).ok();

            // Bundled binaries live under <resources>/binaries.
            let binaries_dir = app
                .path()
                .resource_dir()
                .map(|r| r.join("binaries"))
                .unwrap_or_else(|_| support_dir.clone());

            let engine = Engine {
                support_dir: support_dir.clone(),
                binaries_dir,
            };

            let settings_path = support_dir.join("settings.json");
            let settings: AppSettings = std::fs::read(&settings_path)
                .ok()
                .and_then(|d| serde_json::from_slice(&d).ok())
                .unwrap_or_default();

            let downloads = Arc::new(DownloadManager::new(support_dir.clone()));
            let library = Arc::new(LibraryStore::new(support_dir.clone()));

            app.manage(AppState {
                settings: Mutex::new(settings),
                settings_path,
                engine,
                downloads,
                library,
            });
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::get_settings,
            commands::save_settings,
            commands::default_browser,
            commands::browsers,
            commands::engine_ready,
            commands::engine_status,
            commands::install_engine,
            commands::probe_media,
            commands::list_extractors,
            commands::height_label,
            commands::extract_links,
            commands::get_downloads,
            commands::enqueue_urls,
            commands::enqueue_prepared,
            commands::cancel_download,
            commands::retry_download,
            commands::remove_download,
            commands::clear_history,
            commands::library_browse,
            commands::library_all_media,
            commands::library_rename,
            commands::library_new_folder,
            commands::library_move,
            commands::library_copy,
            commands::library_trash,
            commands::notes_for,
            commands::upsert_note,
            commands::remove_note,
            commands::all_notes,
            commands::positions,
            commands::set_position,
            commands::export_clip,
            commands::export_edit,
            commands::reveal_in_explorer,
            commands::open_path,
        ])
        .run(tauri::generate_context!())
        .expect("error while running Musim");
}
