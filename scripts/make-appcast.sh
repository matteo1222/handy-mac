#!/usr/bin/env bash
# Generates appcast.xml for the notarized zips in a folder with Sparkle's generate_appcast, signing
# each entry with the EdDSA private key from the keychain (created once with Sparkle's generate_keys).
#   scripts/make-appcast.sh .build/release-app https://github.com/<owner>/<repo>/releases/download/v<version>/
set -euo pipefail
cd "$(dirname "$0")/.."
FOLDER=${1:?folder with Handy-<version>.zip}
PREFIX=${2:?download URL prefix for the zips}
TOOL=$(find .build/artifacts -path "*Sparkle*" -name generate_appcast -type f 2>/dev/null | head -1)
[[ -x "$TOOL" ]] || { echo "error: generate_appcast not found; run swift package resolve" >&2; exit 1; }
"$TOOL" --download-url-prefix "$PREFIX" "$FOLDER"
echo "$FOLDER/appcast.xml"
