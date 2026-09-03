# Releasing Musim & auto-update

Musim keeps itself current on two independent layers.

## 1. The download engine (yt-dlp) — always fresh, automatic

yt-dlp goes stale within weeks as sites rotate their streaming (a stale build
starts returning **HTTP 403** on the video stream — the cause of the "download
keeps failing / leaves a `.part` file" bug). Both apps now:

- **Prefer a writable, auto-updated copy** of yt-dlp (in Application Support /
  `%APPDATA%\Musim`) over the one bundled in the app.
- **Check once a day on launch** for a newer yt-dlp release and download it in
  the background.
- **Self-heal**: if a download fails with a stale-engine signature (403,
  "requested format is not available", etc.), refresh yt-dlp and retry once.

This needs no release and no user action — it just works.

macOS: `Sources/Musim/Engine/YtDlp.swift` + `DownloadManager.swift`.
Windows: `windows/src-tauri/src/ytdlp.rs` + `download.rs` + `lib.rs`.

## 2. The app itself — in-app auto-update

- **macOS**: [Sparkle](https://sparkle-project.org). Reads `appcast.xml` from the
  latest GitHub Release, verifies the DMG's EdDSA signature, installs. Checks
  daily; "Check for Updates…" also in the app menu.
- **Windows**: the [Tauri updater](https://v2.tauri.app/plugin/updater/). Reads
  `latest.json` from the latest Release, verifies the minisign signature,
  installs the NSIS setup, relaunches. Prompts on launch when an update exists.

## Cutting a release (auto-repackages BOTH platforms)

Push one semver tag. `.github/workflows/release.yml` builds macOS + Windows,
signs both, generates `appcast.xml` + `latest.json`, and publishes one Release
with every asset.

```bash
git tag v2.1.0
git push origin v2.1.0
```

- The tag (minus `v`) becomes the app version for both platforms.
- macOS `CFBundleVersion` is the CI run number (guaranteed monotonic, so Sparkle
  always sees the new build as newer).
- Use a version **greater than the current macOS 2.0** for the first unified
  release so existing macOS users are offered the update.
- `workflow_dispatch` can rebuild an existing tag from the Actions tab.

## One-time setup: signing secrets (required before the first release)

The signing keys were generated and saved to `~/musim-signing-keys/`
(outside the repo). Public keys are already committed
(`SUPublicEDKey` in `scripts/bundle.sh`, `plugins.updater.pubkey` in
`windows/src-tauri/tauri.conf.json`). Set the **private** keys as repo secrets:

```bash
gh secret set SPARKLE_PRIVATE_KEY               --repo fhmzhroffcl/muatsimpan < ~/musim-signing-keys/sparkle_private_key.pem
gh secret set TAURI_SIGNING_PRIVATE_KEY         --repo fhmzhroffcl/muatsimpan < ~/musim-signing-keys/tauri_updater.key
gh secret set TAURI_SIGNING_PRIVATE_KEY_PASSWORD --repo fhmzhroffcl/muatsimpan --body ""
```

> Back up `~/musim-signing-keys/` somewhere safe. If a private key is lost, users
> on the old key can no longer auto-update and must reinstall manually.

## Building locally

macOS: `./scripts/fetch-binaries.sh && ./scripts/bundle.sh` → `build/Musim.dmg`
Windows: `cd windows && ./scripts/build.ps1`
