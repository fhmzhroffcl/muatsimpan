//! Tauri command surface — the bridge the TypeScript front-end calls via invoke().

use crate::library::{BrowseResult, EditOptions, NoteWithEntry};
use crate::models::{DownloadItem, LibraryEntry, MediaType, StickyNote};
use crate::settings::{self, AppSettings};
use crate::state::AppState;
use crate::ytdlp::{self, MediaProbe};
use std::collections::HashMap;
use tauri::{AppHandle, Manager, State};

// MARK: Settings

#[tauri::command]
pub fn get_settings(state: State<AppState>) -> AppSettings {
    state.settings.lock().unwrap().clone()
}

#[tauri::command]
pub fn save_settings(state: State<AppState>, settings: AppSettings) {
    *state.settings.lock().unwrap() = settings;
    state.persist_settings();
}

#[tauri::command]
pub fn default_browser() -> String {
    settings::default_system_browser()
}

#[tauri::command]
pub fn browsers() -> Vec<String> {
    settings::BROWSERS.iter().map(|s| s.to_string()).collect()
}

// MARK: Engine

#[tauri::command]
pub fn engine_ready(state: State<AppState>) -> bool {
    state.engine.is_ready()
}

#[tauri::command]
pub async fn install_engine(app: AppHandle) -> Result<(), String> {
    let engine = app.state::<AppState>().engine.clone();
    engine.install_ytdlp().await
}

#[tauri::command]
pub async fn probe_media(app: AppHandle, url: String) -> Result<MediaProbe, String> {
    let (engine, settings) = {
        let state = app.state::<AppState>();
        (state.engine.clone(), state.settings.lock().unwrap().clone())
    };
    ytdlp::probe(&url, &settings, &engine).await
}

#[tauri::command]
pub async fn list_extractors(app: AppHandle) -> Vec<String> {
    let engine = app.state::<AppState>().engine.clone();
    ytdlp::list_extractors(&engine).await
}

#[tauri::command]
pub fn height_label(height: i64) -> String {
    ytdlp::height_label(height)
}

#[tauri::command]
pub fn extract_links(text: String) -> Vec<String> {
    crate::models::extract_links(&text)
}

// MARK: Downloads

#[tauri::command]
pub fn get_downloads(state: State<AppState>) -> Vec<DownloadItem> {
    state.downloads.snapshot()
}

#[tauri::command]
pub fn enqueue_urls(app: AppHandle, urls: Vec<String>, media_type: Option<MediaType>) {
    let dl = app.state::<AppState>().downloads.clone();
    dl.enqueue_urls(&app, urls, media_type);
}

#[tauri::command]
pub fn enqueue_prepared(app: AppHandle, items: Vec<DownloadItem>) {
    let dl = app.state::<AppState>().downloads.clone();
    dl.enqueue_prepared(&app, items);
}

#[tauri::command]
pub fn cancel_download(app: AppHandle, id: String) {
    let dl = app.state::<AppState>().downloads.clone();
    dl.cancel(&app, &id);
}

#[tauri::command]
pub fn retry_download(app: AppHandle, id: String) {
    let dl = app.state::<AppState>().downloads.clone();
    dl.retry(&app, &id);
}

#[tauri::command]
pub fn remove_download(app: AppHandle, id: String) {
    let dl = app.state::<AppState>().downloads.clone();
    dl.remove(&app, &id);
}

#[tauri::command]
pub fn clear_history(app: AppHandle) {
    let dl = app.state::<AppState>().downloads.clone();
    dl.clear_history(&app);
}

// MARK: Library

#[tauri::command]
pub fn library_browse(state: State<AppState>, folder: Option<String>) -> BrowseResult {
    let settings = state.settings.lock().unwrap().clone();
    state.library.browse(&settings, folder.as_deref())
}

#[tauri::command]
pub fn library_all_media(state: State<AppState>) -> Vec<LibraryEntry> {
    let settings = state.settings.lock().unwrap().clone();
    state.library.all_media(&settings)
}

#[tauri::command]
pub fn library_rename(state: State<AppState>, path: String, new_name: String) -> Result<(), String> {
    let settings = state.settings.lock().unwrap().clone();
    state.library.rename(&settings, &path, &new_name)
}

#[tauri::command]
pub fn library_new_folder(
    state: State<AppState>,
    parent: Option<String>,
    name: String,
) -> Result<String, String> {
    let settings = state.settings.lock().unwrap().clone();
    state.library.new_folder(&settings, parent.as_deref(), &name)
}

#[tauri::command]
pub fn library_move(state: State<AppState>, paths: Vec<String>, into: String) -> Result<(), String> {
    let settings = state.settings.lock().unwrap().clone();
    state.library.move_paths(&settings, paths, &into)
}

#[tauri::command]
pub fn library_copy(state: State<AppState>, path: String) -> Result<(), String> {
    state.library.copy(&path)
}

#[tauri::command]
pub fn library_trash(state: State<AppState>, path: String) -> Result<(), String> {
    let settings = state.settings.lock().unwrap().clone();
    state.library.trash(&settings, &path)
}

#[tauri::command]
pub fn notes_for(state: State<AppState>, path: String) -> Vec<StickyNote> {
    let settings = state.settings.lock().unwrap().clone();
    state.library.notes_for(&settings, &path)
}

#[tauri::command]
pub fn upsert_note(state: State<AppState>, path: String, note: StickyNote) {
    let settings = state.settings.lock().unwrap().clone();
    state.library.upsert_note(&settings, &path, note);
}

#[tauri::command]
pub fn remove_note(state: State<AppState>, path: String, note_id: String) {
    let settings = state.settings.lock().unwrap().clone();
    state.library.remove_note(&settings, &path, &note_id);
}

#[tauri::command]
pub fn all_notes(state: State<AppState>) -> Vec<NoteWithEntry> {
    let settings = state.settings.lock().unwrap().clone();
    state.library.all_notes(&settings)
}

#[tauri::command]
pub fn positions(state: State<AppState>) -> HashMap<String, [f64; 2]> {
    state.library.positions()
}

#[tauri::command]
pub fn set_position(state: State<AppState>, path: String, x: f64, y: f64) {
    let settings = state.settings.lock().unwrap().clone();
    state.library.set_position(&settings, &path, x, y);
}

#[tauri::command]
pub async fn export_clip(app: AppHandle, path: String, start: f64, end: f64) -> Result<String, String> {
    let engine = app.state::<AppState>().engine.clone();
    crate::library::export_clip(&engine, &path, start, end).await
}

#[tauri::command]
pub async fn export_edit(app: AppHandle, path: String, options: EditOptions) -> Result<String, String> {
    let engine = app.state::<AppState>().engine.clone();
    crate::library::export_edit(&engine, &path, options).await
}

// MARK: File actions

#[tauri::command]
pub fn reveal_in_explorer(path: String) {
    #[cfg(windows)]
    {
        use std::process::Command;
        let _ = Command::new("explorer").arg("/select,").arg(&path).spawn();
    }
    #[cfg(not(windows))]
    {
        let _ = path;
    }
}

#[tauri::command]
pub fn open_path(app: AppHandle, path: String) {
    use tauri_plugin_opener::OpenerExt;
    let _ = app.opener().open_path(path, None::<&str>);
}
