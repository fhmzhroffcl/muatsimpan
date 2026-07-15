// Typed bridge to the Rust backend. Every Tauri command is wrapped here so the
// UI never touches invoke() directly and the type shapes mirror the Rust models.

import { invoke } from "@tauri-apps/api/core";
import { listen, type UnlistenFn } from "@tauri-apps/api/event";
import { convertFileSrc } from "@tauri-apps/api/core";

// ---- Model types (camelCase, matching serde on the Rust side) ----

export type DownloadStatus =
  | "pending"
  | "downloading"
  | "processing"
  | "completed"
  | "error"
  | "cancelled"
  | "paused";

export type MediaType = "video" | "audio";
export type QualityPreset = "best" | "good" | "normal" | "low";
export type ContainerOption = "auto" | "mp4" | "mkv" | "webm" | "original";
export type Platform =
  | "youtube" | "tiktok" | "instagram" | "twitter" | "facebook" | "bilibili"
  | "vimeo" | "twitch" | "soundcloud" | "reddit" | "dailymotion" | "generic";

export interface DownloadProgressInfo {
  percent: number;
  speed?: string | null;
  eta?: string | null;
  downloaded?: string | null;
  total?: string | null;
}

export interface DownloadItem {
  id: string;
  url: string;
  title: string;
  thumbnailUrl?: string | null;
  type: MediaType;
  status: DownloadStatus;
  progress: DownloadProgressInfo;
  errorMessage?: string | null;
  log: string;
  duration?: number | null;
  fileSize?: number | null;
  savedFilePath?: string | null;
  uploader?: string | null;
  channel?: string | null;
  descriptionText?: string | null;
  viewCount?: number | null;
  platform: Platform;
  formatNote?: string | null;
  ext?: string | null;
  audioFormat?: string | null;
  quality: QualityPreset;
  container: ContainerOption;
  formatSelector?: string | null;
  qualityLabel?: string | null;
  estimatedSize?: number | null;
  createdAt: number;
  completedAt?: number | null;
}

export type AppLanguage = "malay" | "english";
export type AppAppearance = "system" | "light" | "dark";
export type HistoryLogFrequency = "never" | "daily" | "weekly" | "monthly";

export interface AppSettings {
  onboardingCompleted: boolean;
  userName: string;
  downloadPath: string;
  maxConcurrentDownloads: number;
  browserForCookies: string;
  proxy: string;
  filenameTemplate: string;
  autoNaming: boolean;
  oneClickType: MediaType;
  oneClickQuality: QualityPreset;
  container: ContainerOption;
  embedSubs: boolean;
  embedThumbnail: boolean;
  embedMetadata: boolean;
  embedChapters: boolean;
  notifyOnComplete: boolean;
  channelSubfolders: boolean;
  organizeByPlatform: boolean;
  language: AppLanguage;
  appearance: AppAppearance;
  accent: string;
  pattern: string;
  autoUpdateEngine: boolean;
  historyLog: HistoryLogFrequency;
  advancedNaming: boolean;
  namePrefix: string;
  nameSuffix: string;
  nameSeparator: string;
  nameDate: string;
  nameCounter: boolean;
}

export interface ProbedFormat {
  id: string;
  height?: number | null;
  ext: string;
  vcodec?: string | null;
  acodec?: string | null;
  filesize?: number | null;
  note?: string | null;
  fps?: number | null;
}

export interface MediaProbe {
  title: string;
  thumbnail?: string | null;
  description?: string | null;
  uploader?: string | null;
  channel?: string | null;
  duration?: number | null;
  viewCount?: number | null;
  formats: ProbedFormat[];
  heights: number[];
}

export type NoteSize = "square" | "wide" | "big" | "tall";
export interface StickyNote {
  id: string;
  text: string;
  color: string;
  size: NoteSize;
  html?: string | null;
}

export interface LibraryEntry {
  id: string;
  path: string;
  name: string;
  isFolder: boolean;
  size: number;
  modified: number;
  isMedia: boolean;
}

export interface BrowseResult {
  entries: LibraryEntry[];
  currentFolder: string;
  root: string;
  isAtRoot: boolean;
}

export interface NoteWithEntry {
  entry: LibraryEntry;
  note: StickyNote;
}

export interface EditOptions {
  start: number;
  end: number;
  speed?: number;
  aspect?: string;
  maxHeight?: number | null;
  cropX?: number;
  cropY?: number;
}

// ---- Command wrappers ----

export const api = {
  // settings
  getSettings: () => invoke<AppSettings>("get_settings"),
  saveSettings: (settings: AppSettings) => invoke<void>("save_settings", { settings }),
  defaultBrowser: () => invoke<string>("default_browser"),
  browsers: () => invoke<string[]>("browsers"),

  // engine
  engineReady: () => invoke<boolean>("engine_ready"),
  installEngine: () => invoke<void>("install_engine"),
  probeMedia: (url: string) => invoke<MediaProbe>("probe_media", { url }),
  listExtractors: () => invoke<string[]>("list_extractors"),
  heightLabel: (height: number) => invoke<string>("height_label", { height }),
  extractLinks: (text: string) => invoke<string[]>("extract_links", { text }),

  // downloads
  getDownloads: () => invoke<DownloadItem[]>("get_downloads"),
  enqueueUrls: (urls: string[], mediaType?: MediaType) =>
    invoke<void>("enqueue_urls", { urls, mediaType: mediaType ?? null }),
  enqueuePrepared: (items: DownloadItem[]) => invoke<void>("enqueue_prepared", { items }),
  cancelDownload: (id: string) => invoke<void>("cancel_download", { id }),
  retryDownload: (id: string) => invoke<void>("retry_download", { id }),
  removeDownload: (id: string) => invoke<void>("remove_download", { id }),
  clearHistory: () => invoke<void>("clear_history"),

  // library
  libraryBrowse: (folder?: string) => invoke<BrowseResult>("library_browse", { folder: folder ?? null }),
  libraryAllMedia: () => invoke<LibraryEntry[]>("library_all_media"),
  libraryRename: (path: string, newName: string) => invoke<void>("library_rename", { path, newName }),
  libraryNewFolder: (parent: string | null, name: string) =>
    invoke<string>("library_new_folder", { parent, name }),
  libraryMove: (paths: string[], into: string) => invoke<void>("library_move", { paths, into }),
  libraryCopy: (path: string) => invoke<void>("library_copy", { path }),
  libraryTrash: (path: string) => invoke<void>("library_trash", { path }),
  notesFor: (path: string) => invoke<StickyNote[]>("notes_for", { path }),
  upsertNote: (path: string, note: StickyNote) => invoke<void>("upsert_note", { path, note }),
  removeNote: (path: string, noteId: string) => invoke<void>("remove_note", { path, noteId }),
  allNotes: () => invoke<NoteWithEntry[]>("all_notes"),
  positions: () => invoke<Record<string, [number, number]>>("positions"),
  setPosition: (path: string, x: number, y: number) => invoke<void>("set_position", { path, x, y }),
  exportClip: (path: string, start: number, end: number) =>
    invoke<string>("export_clip", { path, start, end }),
  exportEdit: (path: string, options: EditOptions) => invoke<string>("export_edit", { path, options }),

  // file actions
  revealInExplorer: (path: string) => invoke<void>("reveal_in_explorer", { path }),
  openPath: (path: string) => invoke<void>("open_path", { path }),
};

// ---- Events ----

export function onDownloadsUpdated(cb: (items: DownloadItem[]) => void): Promise<UnlistenFn> {
  return listen<DownloadItem[]>("downloads-updated", (e) => cb(e.payload));
}

export function onLibraryShouldRefresh(cb: () => void): Promise<UnlistenFn> {
  return listen("library-should-refresh", () => cb());
}

// Convert a real filesystem path into an asset: URL playable in <img>/<video>.
export function fileSrc(path: string): string {
  return convertFileSrc(path);
}
