# Musim launch storyboard — 24 seconds

| Time | Real Musim surface | Motion | Audio marker |
|---|---|---|---|
| 0.0–2.8 | `SplashView`, `MusimLogo` | Logo tile and hidden-titlebar app window materialise | soft intro swell |
| 2.8–5.2 | `DownloadPanel` | Gentle push-in on greeting and paste/fetch bar | subtle UI click |
| 5.2–9.0 | Fetching indicator + `PendingCard` | Cursor pastes a YouTube URL, then live fetch state resolves to metadata | soft UI click, metadata ready |
| 9.0–11.8 | `PendingCard.controls` | Hover 1080p, select MP4, press “Muat turun ini” | format selection, download start |
| 11.8–15.5 | `DownloadRow`, `ActivityDockLabel`, `FloatingActivityWindow` | Deterministic 0→76→100% progress and expanded Activity window | download start, progress completion |
| 15.5–18.5 | `LibraryView` Media | Completed media enters the Photos-style media grid | success chime |
| 18.5–21.6 | `EditorTabView` | Existing editor focus: trim range, 1.5× speed, 9:16 format, 1080p | editor adjustment |
| 21.6–24.0 | `MainView` Download | Return to real dashboard, logo and restrained tagline | final soft resolution |

## Feature exports

- `download-flow` — 12 seconds, URL → metadata → chosen format.
- `download-progress` — 11 seconds, start → Activity dock/window → completion.
- `library` — 10 seconds, completed item → media grid.
- `editor` — 12 seconds, timeline trim → speed/aspect/resolution controls.

All feature exports use the same deterministic local sample media data and source-derived UI.
