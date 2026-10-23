#!/usr/bin/env bash
# Builds the Handy executable with SwiftPM and assembles a signed menu-bar .app bundle.
# Usage: scripts/package-app.sh [debug|release]
# Env: APP_IDENTITY (Developer ID for releases), DEV_IDENTITY (debug builds; defaults to the keychain's
#      first "Apple Development" identity, ad-hoc when there is none), OUT_DIR (default .build/app),
#      SPARKLE_FEED_URL and SPARKLE_PUBLIC_KEY (release builds only; without them updates stay off)
set -euo pipefail
cd "$(dirname "$0")/.."

CONF=${1:-debug}
OUT_DIR=${OUT_DIR:-.build/app}
APP_IDENTITY=${APP_IDENTITY:-}
SPARKLE_FEED_URL=${SPARKLE_FEED_URL:-}
SPARKLE_PUBLIC_KEY=${SPARKLE_PUBLIC_KEY:-}
source version.env

swift build -c "$CONF" --product Handy
BIN_DIR=$(swift build -c "$CONF" --show-bin-path)

APP="$OUT_DIR/Handy.app"
if [[ -d "$APP" ]]; then mv "$APP" "$(mktemp -d)/"; fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN_DIR/Handy" "$APP/Contents/MacOS/Handy"
shopt -s nullglob
for bundle in "$BIN_DIR"/*.bundle; do
  [[ "$bundle" == *Tests.bundle ]] || cp -R "$bundle" "$APP/Contents/Resources/"
done
for framework in "$BIN_DIR"/*.framework; do cp -R "$framework" "$APP/Contents/Frameworks/"; done
shopt -u nullglob
if ! otool -l "$APP/Contents/MacOS/Handy" | grep -q "@executable_path/../Frameworks"; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/Handy"
fi

SPARKLE_KEYS=""
if [[ -n "$SPARKLE_FEED_URL" && -n "$SPARKLE_PUBLIC_KEY" ]]; then
  SPARKLE_KEYS="<key>SUFeedURL</key><string>${SPARKLE_FEED_URL}</string>
    <key>SUPublicEDKey</key><string>${SPARKLE_PUBLIC_KEY}</string>
    <key>SUEnableAutomaticChecks</key><true/>"
fi

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
    ${SPARKLE_KEYS}
</dict>
</plist>
PLIST

scripts/appintents-metadata.sh "$APP" "$CONF" >/dev/null

xattr -cr "$APP"
# A certificate-signed build keeps its camera and Accessibility grants across rebuilds. Ad-hoc code is
# identified by its hash: naming only the bundle ID keeps the camera grant, but Accessibility still
# compares the hash, so debug builds prefer an Apple Development certificate when the keychain has one.
DEV_IDENTITY=${DEV_IDENTITY-$(security find-identity -p codesigning -v 2>/dev/null \
  | sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' | head -1)}
APP_REQUIREMENT=()
if [[ -n "$APP_IDENTITY" ]]; then
  SIGN=(--force --timestamp --options runtime --sign "$APP_IDENTITY")
elif [[ -n "$DEV_IDENTITY" ]]; then
  SIGN=(--force --sign "$DEV_IDENTITY")
else
  SIGN=(--force --sign -)
  APP_REQUIREMENT=(-r='designated => identifier "dev.handy.Handy"')
fi
# Sign nested code inside-out: helpers and XPC services, then each framework, then the app.
for framework in "$APP"/Contents/Frameworks/*.framework; do
  [[ -d "$framework" ]] || continue
  while IFS= read -r -d '' nested; do
    codesign "${SIGN[@]}" "$nested"
  done < <(find "$framework" \( -name "*.xpc" -o -name "*.app" \) -prune -print0)
  while IFS= read -r -d '' binary; do
    codesign "${SIGN[@]}" "$binary"
  # -H: Versions/Current is a symlink, and find does not descend into a symlinked start path
  # without it (Sparkle's Autoupdate went unsigned and notarization rejected the app).
  done < <(find -H "$framework/Versions/Current" -maxdepth 1 -type f -perm -111 -print0 2>/dev/null)
  codesign "${SIGN[@]}" "$framework"
done
codesign "${SIGN[@]}" ${APP_REQUIREMENT[@]+"${APP_REQUIREMENT[@]}"} --entitlements Resources/Handy.entitlements "$APP"
echo "$APP"
