#!/bin/bash
# Builds "Zayn Letter Adventure.app": a full-screen, kid-safe Mac app around Zayn-Letter-Adventure.html.
# Run it from Terminal:   bash build.sh
set -e
cd "$(dirname "$0")"

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo ""
  echo "First, Apple's free developer tools need to be installed."
  echo "A window will pop up: click Install, wait until it finishes (about 5-10 minutes),"
  echo "then run   bash build.sh   again."
  xcode-select --install 2>/dev/null || true
  exit 1
fi

HTML="../Zayn-Letter-Adventure.html"
[ -f "$HTML" ] || HTML="Zayn-Letter-Adventure.html"
if [ ! -f "$HTML" ]; then echo "Can't find Zayn-Letter-Adventure.html next to this folder."; exit 1; fi

APP="Zayn Letter Adventure.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Building the app..."
# one app that runs on both Apple-chip and Intel Macs
BIN="$APP/Contents/MacOS/ZaynLetterAdventure"
if xcrun swiftc -O -swift-version 5 -target arm64-apple-macos11.0 main.swift -o /tmp/zla-arm64 2>/tmp/zla-arm.log \
   && xcrun swiftc -O -swift-version 5 -target x86_64-apple-macos11.0 main.swift -o /tmp/zla-x86 2>/tmp/zla-x86.log; then
  lipo -create /tmp/zla-arm64 /tmp/zla-x86 -output "$BIN"
else
  cat /tmp/zla-arm.log /tmp/zla-x86.log 2>/dev/null
  xcrun swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos11.0" main.swift -o "$BIN"
fi
cp "$HTML" "$APP/Contents/Resources/Zayn-Letter-Adventure.html"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>ZaynLetterAdventure</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIdentifier</key><string>home.family.zaynletteradventure</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>Zayn Letter Adventure</string>
  <key>CFBundleDisplayName</key><string>Zayn Letter Adventure</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>5.0</string>
  <key>CFBundleVersion</key><string>5</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.education</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>So a grown-up can record how to say new words for Zayn.</string>
</dict>
</plist>
PLIST

if [ -f icon.png ]; then
  echo "Making the icon..."
  ICONSET="$(mktemp -d)/AppIcon.iconset"; mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    sips -z $s $s icon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) icon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns" || echo "(icon skipped)"
fi

xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo ""
echo "Done! \"$APP\" is in this folder."
echo "Drag it into your Applications folder, then double-click it to play."
echo "To quit: hold the gear for 2 seconds and press Quit, or press Control + Option + Command + Q."
[ -z "$CI" ] && open -R "$APP" 2>/dev/null || true
