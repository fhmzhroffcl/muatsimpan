# Downloads the Windows command-line tools Musim bundles (yt-dlp, ffmpeg,
# ffprobe, deno) into src-tauri/binaries so they ship inside the installer.
# Run from the windows/ directory (or let CI call it).

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$binDir = Join-Path $here "..\src-tauri\binaries"
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

function Get-File($url, $out) {
  Write-Host "Downloading $url"
  Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
}

# --- yt-dlp ---
Get-File "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" (Join-Path $binDir "yt-dlp.exe")

# --- ffmpeg + ffprobe (BtbN static GPL build) ---
$tmp = Join-Path $env:TEMP "ffmpeg.zip"
Get-File "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip" $tmp
$ex = Join-Path $env:TEMP "ffmpeg_extract"
if (Test-Path $ex) { Remove-Item -Recurse -Force $ex }
Expand-Archive -Path $tmp -DestinationPath $ex -Force
$ff = Get-ChildItem -Path $ex -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1
$fp = Get-ChildItem -Path $ex -Recurse -Filter "ffprobe.exe" | Select-Object -First 1
Copy-Item $ff.FullName (Join-Path $binDir "ffmpeg.exe") -Force
Copy-Item $fp.FullName (Join-Path $binDir "ffprobe.exe") -Force

# --- deno (YouTube JS n-challenge runtime) ---
$dtmp = Join-Path $env:TEMP "deno.zip"
Get-File "https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip" $dtmp
$dex = Join-Path $env:TEMP "deno_extract"
if (Test-Path $dex) { Remove-Item -Recurse -Force $dex }
Expand-Archive -Path $dtmp -DestinationPath $dex -Force
Copy-Item (Join-Path $dex "deno.exe") (Join-Path $binDir "deno.exe") -Force

Write-Host "Binaries ready in $binDir"
Get-ChildItem $binDir | Select-Object Name, Length
