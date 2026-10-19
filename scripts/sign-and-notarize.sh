#!/usr/bin/env bash
# Builds a release Handy.app, signs it with Developer ID (hardened runtime), notarizes, staples and
# zips it. Needs a Developer ID Application identity in the keychain and a notarytool profile.
#
#   APP_IDENTITY="Developer ID Application: Name (TEAMID)" NOTARY_PROFILE=handy \
#   SPARKLE_FEED_URL=https://github.com/<owner>/<repo>/releases/latest/download/appcast.xml \
#   SPARKLE_PUBLIC_KEY=<base64 EdDSA public key> scripts/sign-and-notarize.sh
#
# Create the notary profile once:  xcrun notarytool store-credentials handy --apple-id ... --team-id ...
set -euo pipefail
cd "$(dirname "$0")/.."
: "${APP_IDENTITY:?set APP_IDENTITY to your Developer ID Application identity}"
: "${NOTARY_PROFILE:?set NOTARY_PROFILE to a notarytool keychain profile}"
: "${SPARKLE_FEED_URL:?set SPARKLE_FEED_URL}"
: "${SPARKLE_PUBLIC_KEY:?set SPARKLE_PUBLIC_KEY}"
source version.env

OUT_DIR=.build/release-app scripts/package-app.sh release
APP=.build/release-app/Handy.app
ZIP=.build/release-app/Handy-$MARKETING_VERSION.zip

codesign --verify --deep --strict --verbose=2 "$APP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose "$APP"
mv "$ZIP" "$ZIP.unstapled"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "$ZIP"
