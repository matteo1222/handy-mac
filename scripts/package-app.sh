#!/usr/bin/env bash
# Builds the Handy executable with SwiftPM and assembles a signed menu-bar .app bundle.
# Usage: scripts/package-app.sh [debug|release]
# Env: APP_IDENTITY (Developer ID; ad-hoc signed when unset), OUT_DIR (default .build/app)
set -euo pipefail
cd "$(dirname "$0")/.."

CONF=${1:-debug}
OUT_DIR=${OUT_DIR:-.build/app}
APP_IDENTITY=${APP_IDENTITY:-}
source version.env

swift build -c "$CONF" --product Handy
BIN_DIR=$(swift build -c "$CONF" --show-bin-path)

APP="$OUT_DIR/Handy.app"
if [[ -d "$APP" ]]; then mv "$APP" "$(mktemp -d)/"; fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Handy" "$APP/Contents/MacOS/Handy"
shopt -s nullglob
for bundle in "$BIN_DIR"/*.bundle; do cp -R "$bundle" "$APP/Contents/Resources/"; done
shopt -u nullglob

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Handy</string>
    <key>CFBundleDisplayName</key><string>Handy</string>
    <key>CFBundleIdentifier</key><string>dev.handy.Handy</string>
    <key>CFBundleExecutable</key><string>Handy</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSCameraUsageDescription</key><string>Handy reads your hand pose from the camera to move the pointer. Frames stay in memory and are never saved or sent.</string>
</dict>
</plist>
PLIST

xattr -cr "$APP"
if [[ -n "$APP_IDENTITY" ]]; then
  codesign --force --timestamp --options runtime --entitlements Resources/Handy.entitlements --sign "$APP_IDENTITY" "$APP"
else
  codesign --force --entitlements Resources/Handy.entitlements --sign - "$APP"
fi
echo "$APP"
