#!/bin/zsh
# Fetch the macOS command-line tools Musim bundles (yt-dlp, ffmpeg, ffprobe,
# deno) into Vendor/ so scripts/bundle.sh can package them. Used by CI; the
# binaries are intentionally excluded from Git. Apple Silicon (arm64) only.
set -e
cd "$(dirname "$0")/.."
mkdir -p Vendor
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

extract_one() {  # <zip> <basename> <dest>
  unzip -o "$1" -d "$tmp/x_$2" >/dev/null
  cp "$(find "$tmp/x_$2" -name "$2" -type f | head -1)" "$3"
}

echo "==> yt-dlp (universal)"
curl -fsSL -o Vendor/yt-dlp "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos"

echo "==> ffmpeg + ffprobe (static arm64)"
curl -fsSL -o "$tmp/ffmpeg.zip"  "https://ffmpeg.martin-riedl.de/redirect/latest/macos/arm64/release/ffmpeg.zip"
curl -fsSL -o "$tmp/ffprobe.zip" "https://ffmpeg.martin-riedl.de/redirect/latest/macos/arm64/release/ffprobe.zip"
extract_one "$tmp/ffmpeg.zip"  ffmpeg  Vendor/ffmpeg
extract_one "$tmp/ffprobe.zip" ffprobe Vendor/ffprobe

echo "==> deno (arm64)"
curl -fsSL -o "$tmp/deno.zip" "https://github.com/denoland/deno/releases/latest/download/deno-aarch64-apple-darwin.zip"
extract_one "$tmp/deno.zip" deno Vendor/deno

chmod +x Vendor/yt-dlp Vendor/ffmpeg Vendor/ffprobe Vendor/deno
xattr -cr Vendor/yt-dlp Vendor/ffmpeg Vendor/ffprobe Vendor/deno 2>/dev/null || true
echo "Vendor ready:"; ls -la Vendor
