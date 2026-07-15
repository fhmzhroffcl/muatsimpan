# Musim for Windows

Native Windows build of Musim (Muat + Simpan), rebuilt on **Tauri** (Rust core +
web UI) so it compiles to a real Windows `.exe`. Same features and behaviour as
the macOS SwiftUI app; the front-end is re-implemented because SwiftUI/AppKit do
not exist on Windows.

## What produces the `.exe`

Two artifacts come out of a build:

- `src-tauri/target/release/musim.exe` — the portable executable.
- `src-tauri/target/release/bundle/nsis/Musim_1.0.0_x64-setup.exe` — the installer.

## Building the exe

You need **Windows** to produce a Windows binary (Tauri links against WebView2 and
the MSVC toolchain — it does not cross-compile from macOS). Two supported paths:

### 1. GitHub Actions (recommended if you're on a Mac)

Push this repo to GitHub. The workflow at
[`.github/workflows/windows-build.yml`](../.github/workflows/windows-build.yml)
runs on a Windows runner, fetches the bundled tools, builds, and uploads both the
portable exe and the installer as downloadable artifacts. You can also trigger it
manually from the Actions tab (**Run workflow** → `workflow_dispatch`).

### 2. On a Windows machine

Install [Rust](https://rustup.rs), Node 20+, and pnpm (`npm i -g pnpm`), then:

```powershell
cd windows
./scripts/build.ps1
```

The script downloads the bundled binaries, generates icons from the shared logo,
and runs `pnpm tauri build`.

## Architecture

| Layer | macOS (Swift) | Windows (this build) |
| --- | --- | --- |
| UI | SwiftUI / AppKit | React + TypeScript (Vite) |
| Core/engine | `DownloadManager`, `YtDlp`, `LibraryStore` | Rust (`src-tauri/src/*.rs`) |
| Media tools | bundled yt-dlp / ffmpeg (Mach-O) | bundled yt-dlp.exe / ffmpeg.exe / ffprobe.exe / deno.exe |
| Clip/edit | AVFoundation | ffmpeg |
| Notifications | UserNotifications | `tauri-plugin-notification` |
| Settings store | UserDefaults | `%APPDATA%\Musim\settings.json` |

Support files (history, notes, positions, reports) live in `%APPDATA%\Musim`,
mirroring the macOS `~/Library/Application Support/Musim` layout.

## Build phases

- **Phase 1 (done):** Rust port of the entire engine + a working app shell that
  installs yt-dlp, enqueues links, and shows live progress. This is what's here now.
- **Phase 2+:** the full three-column UI — splash, onboarding, download panel,
  activity dock, library (folders/media/notes canvas), clip editor, settings, and
  the guide — rebuilt to match the SwiftUI design, using the tokens already ported
  in `src/styles/theme.css`.
