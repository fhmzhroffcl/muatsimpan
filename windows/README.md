# Musim for Windows

Native Windows build of Musim (Muat + Simpan), rebuilt on **Tauri** (Rust core +
web UI) so it compiles to a real Windows `.exe`. Same features and behaviour as
the macOS SwiftUI app; the front-end is re-implemented because SwiftUI/AppKit do
not exist on Windows.

## What produces the `.exe`

Two artifacts come out of a build:

- `src-tauri/target/release/musim.exe` — the portable executable.
- `src-tauri/target/release/bundle/nsis/Musim_1.0.0_x64-setup.exe` — the installer.

## Download the Windows build

The first unsigned Windows build is available from the
[Musim for Windows v1.0.0 release](https://github.com/fhmzhroffcl/muatsimpan/releases/tag/windows-v1.0.0):

- [Portable `musim.exe`](https://github.com/fhmzhroffcl/muatsimpan/releases/download/windows-v1.0.0/musim.exe)
- [Windows setup installer](https://github.com/fhmzhroffcl/muatsimpan/releases/download/windows-v1.0.0/Musim_1.0.0_x64-setup.exe)

This community build is not code-signed, so Windows SmartScreen may ask for
confirmation before the first launch.

| File | SHA-256 |
| --- | --- |
| `musim.exe` | `55b4c810fa2736e9b4034f46a0872c1999cb2a4c900170e32a21a78fed165c84` |
| `Musim_1.0.0_x64-setup.exe` | `f53c48617c70fc128f5f7f20ed320fe010d5fae7ca6fc7b735ec554782b35366` |

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

Install [Rust](https://rustup.rs) and Node 20+, then:

```powershell
cd windows
./scripts/build.ps1
```

The script downloads the bundled binaries and runs `npm run tauri build`. Icons
are committed under `src-tauri/icons`, so no generation step is needed.

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
