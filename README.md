# Musim (Muat + Simpan)

Musim turns the things you save into a media library you actually own. Paste a link to save video or audio from 1,000+ sites, then keep it organized with folders, a built-in player and video editor, sticky notes, and archive insights—all on your Mac, with no ads and no tracking.

Musim is a private, local-first media archive for macOS. It is free, ad-free, offline-first, and built as a native Apple Silicon app.

## Features

- **Save from 1,000+ sites** — paste one or many links; supported sources include YT, FB, TT, IG, X, SC, and many more.
- **A real library, not a downloads folder** — folder canvas with drag and drop, a Photos-style timeline, rename-on-disk, and search across name, format, source, and channel.
- **Built-in video player** — watch saved media without leaving Musim.
- **Two-panel video editor** — trim, crop, aspect ratio, speed, resolution, and export through AVFoundation.
- **Sticky notes and labels** on your media.
- **Archive insights** — video/audio split, top sources, top formats, storage, and interactive charts.
- **Smart organization** — auto-foldering by platform and creator, filename templates, subtitle/thumbnail/metadata embedding.
- **Bilingual** — Bahasa Melayu and English.
- **Fully local** — no ads, no tracking, and files saved to a folder you choose.

## Build and run

Requirements: macOS 14 or newer and an Apple Silicon Mac. Swift Command Line Tools are sufficient for the native build.

```zsh
./scripts/bundle.sh
open build/Musim.app
```

The packaging script expects the third-party executables in `Vendor/` for local builds. These binaries are intentionally excluded from Git. The app can fetch its media engine on first launch; FFmpeg is also used for media processing and editor export.

The current Apple Silicon DMG is published under the repository's [GitHub Releases](https://github.com/fhmzhroffcl/muatsimpan/releases).

## Source and licensing

Musim's Swift source is released under the MIT License; see [LICENSE](LICENSE).

The app uses FFmpeg, yt-dlp, Deno, and adapted yt-dlp argument logic inspired by [VidBee](https://github.com/nexmoe/VidBee). The download engine is inspired by VidBee, not a VidBee wrapper. Copyright and licenses for each project remain with their holders; see [legal/NOTICE.md](legal/NOTICE.md).

Musim shells out to FFmpeg as a separate process rather than linking it into the application. The FFmpeg binary distributed in a release remains covered by its own GPLv3 terms. See the notice for the exact build information and source-code offer.

## Privacy and responsible use

Musim is designed for media you own or are licensed and permitted to keep: your own uploads, public or Creative Commons material, and authorised backups. It saves files locally and does not add analytics or tracking. See [legal/PRIVACY.md](legal/PRIVACY.md) and [legal/TERMS.md](legal/TERMS.md).

## Credits

Built on open source — yt-dlp, FFmpeg, and Deno. The download engine is inspired by [VidBee](https://github.com/nexmoe/VidBee). Copyright and licenses for each project remain with their holders (see the in-app **Licenses** tab / [legal/NOTICE.md](legal/NOTICE.md)).

Musim is a WartaAI project by Fahim Zahar.
