# One-shot local build for a Windows machine. Produces:
#   src-tauri\target\release\musim.exe                     (portable exe)
#   src-tauri\target\release\bundle\nsis\Musim_*_x64-setup.exe  (installer)
#
# Prerequisites (install once):
#   - Rust (https://rustup.rs)  -> rustup default stable
#   - Node.js 20+ and pnpm      -> npm i -g pnpm
#   - WebView2 runtime (preinstalled on Windows 11)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $here "..")

Write-Host "==> Fetching bundled binaries"
& (Join-Path $here "fetch-binaries.ps1")

Write-Host "==> Installing JS dependencies"
pnpm install

# Generate app icons from the shared logo if they are not present yet.
if (-not (Test-Path "src-tauri\icons\icon.ico")) {
  $logo = Join-Path $here "..\..\must simpan ico.png"
  if (Test-Path $logo) {
    Write-Host "==> Generating icons from $logo"
    pnpm tauri icon "$logo"
  }
}

Write-Host "==> Building (this compiles Rust in release; first run is slow)"
pnpm tauri build

Write-Host "`nDone. Look in src-tauri\target\release for musim.exe and bundle\nsis for the installer."
