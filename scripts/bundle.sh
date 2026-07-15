#!/bin/zsh
# Package the SwiftPM-built binary into Musim.app
set -e
cd "$(dirname "$0")/.."
APP="build/Musim.app"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Musim "$APP/Contents/MacOS/Musim"

# built-in download engine (yt-dlp + ffmpeg + ffprobe + Deno JS runtime)
cp Vendor/yt-dlp Vendor/ffmpeg Vendor/ffprobe Vendor/deno "$APP/Contents/Resources/"
xattr -cr "$APP/Contents/Resources/yt-dlp" "$APP/Contents/Resources/ffmpeg" \
         "$APP/Contents/Resources/ffprobe" "$APP/Contents/Resources/deno"

# brand assets: splash logo-reveal video + logo images.
# Prefer the newest splash video if present.
if [ -f "new logo/new logo.mp4" ]; then
  cp "new logo/new logo.mp4" "$APP/Contents/Resources/splash.mp4"
  echo "Splash: new logo/new logo.mp4"
else
  cp "logo.mp4" "$APP/Contents/Resources/splash.mp4"
fi
cp "musim trans.png" "$APP/Contents/Resources/logo.png"

# onboarding audio — bundled for the first-run walkthrough.
for a in "audio/musim.MP3" "audio/musim.mp3" "onboarding-audio.mp3" "onboarding-audio.m4a" "onboarding-audio.wav" "onboarding-audio.aac" "onboarding-audio.caf"; do
  if [ -f "$a" ]; then
    mkdir -p "$APP/Contents/Resources/audio"
    ext="${a##*.}"
    cp "$a" "$APP/Contents/Resources/audio/musim.$ext"
    cp "$a" "$APP/Contents/Resources/onboarding-audio.$ext"
    echo "Onboarding audio: $a"
    break
  fi
done

# support QR (DuitNow) — optional; the About > Support screen shows it if present.
# Accepts a few common filenames; bundles it as duitnow.png.
for q in "duitnow.png" "fahim QR.png" "duitnow-qr.png" "qr.png" "support-qr.png" "duitnow qr.png"; do
  [ -f "$q" ] && cp "$q" "$APP/Contents/Resources/duitnow.png" && echo "Support QR: $q" && break
done

# official platform logos for the Supported Sites carousel
if [ -d logos ]; then
  mkdir -p "$APP/Contents/Resources/logos"
  cp logos/*.png "$APP/Contents/Resources/logos/" 2>/dev/null || true
  echo "Logos: $(ls logos/*.png 2>/dev/null | wc -l | tr -d ' ') bundled"
fi

# legal documents shown in the About modal
if [ -d legal ]; then
  cp legal/PRIVACY.md legal/TERMS.md legal/NOTICE.md "$APP/Contents/Resources/" 2>/dev/null || true
  echo "Legal docs bundled"
fi

# icon — composite the brand logo into a native rounded-square icon.
# Pick the first icon source that exists (asset filenames have changed over time).
ICON_SRC=""
for c in "muat simpan black.png" "must simpan ico.png" "MuatSimpan.png" "musim trans.png" "logo.png"; do
  [ -f "$c" ] && ICON_SRC="$c" && break
done
if [ -n "$ICON_SRC" ]; then
  echo "Icon source: $ICON_SRC"
  rm -f build/icon.icns
  mkdir -p build/icon.iconset
  swift scripts/make-icon.swift "$ICON_SRC" build/icon-1024.png
  for s in 16 32 64 128 256 512; do
    sips -z $s $s build/icon-1024.png --out "build/icon.iconset/icon_${s}x${s}.png" >/dev/null
    d=$((s*2))
    sips -z $d $d build/icon-1024.png --out "build/icon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns build/icon.iconset -o build/icon.icns
  cp build/icon.icns "$APP/Contents/Resources/icon.icns"
else
  echo "⚠️  No icon source PNG found — skipping app icon."
fi

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Musim</string>
    <key>CFBundleIdentifier</key><string>com.fz.musim</string>
    <key>CFBundleName</key><string>Musim</string>
    <key>CFBundleDisplayName</key><string>Musim</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>2.0</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>CFBundleIconFile</key><string>icon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>Musim — Muat + Simpan</string>
</dict>
</plist>
EOF

# Remove inherited download/provenance metadata from every bundled resource
# before sealing the bundle. This keeps the local sideload artifact clean;
# Developer ID signing and notarization are still required for Gatekeeper trust.
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
echo "✅ Bundled: $PWD/$APP"

# Disk image (drag-to-Applications) for handing the build to testers.
# Ad-hoc signed like the .app — testers still clear Gatekeeper via
# System Settings › Privacy & Security until the app is notarized.
DMG="build/Musim.dmg"
STAGE="build/dmg-staging"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Musim.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Musim" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
echo "💿 Disk image: $PWD/$DMG"
