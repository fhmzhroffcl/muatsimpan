# One-shot local build for a Windows machine. Produces:
#   src-tauri\target\release\musim.exe                          (portable exe)
#   src-tauri\target\release\bundle\nsis\Musim_*_x64-setup.exe  (installer)
#
# Prerequisites (install once):
#   - Rust (https://rustup.rs)  -> rustup default stable
#   - Node.js 20+
#   - WebView2 runtime (preinstalled on Windows 11)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $here "..")

Write-Host "==> Fetching bundled binaries"
& (Join-Path $here "fetch-binaries.ps1")

Write-Host "==> Installing JS dependencies"
npm ci

Write-Host "==> Building (this compiles Rust in release; first run is slow)"
npm run tauri build

Write-Host "`nDone. Look in src-tauri\target\release for musim.exe and bundle\nsis for the installer."
