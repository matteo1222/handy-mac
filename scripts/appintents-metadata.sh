#!/usr/bin/env bash
# Extracts App Intents metadata for HandyApp into <app>/Contents/Resources, which Xcode would do in a
# build phase. SwiftPM does not, so: compile HandyApp's sources once more as a single module to get the
# compiler's constant values, then run Apple's appintentsmetadataprocessor on them.
#   scripts/appintents-metadata.sh .build/app/Handy.app [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."
APP=${1:?path to Handy.app}
CONF=${2:-debug}
BIN=$(swift build -c "$CONF" --show-bin-path)
WORK=$(mktemp -d)
SDK=$(xcrun --show-sdk-path)
TOOLCHAIN=$(cd "$(dirname "$(xcrun --find swiftc)")/../.." && pwd)
XCODE_BUILD=$(xcodebuild -version | awk '/Build version/ {print $3}')

find "$PWD/Sources/HandyApp" -name "*.swift" | sort > "$WORK/sources.txt"
echo '["AppIntent","AppEntity","AppEnum","AppShortcutsProvider","TransientAppEntity","EntityQuery"]' > "$WORK/protocols.json"
xcrun swiftc -wmo -parse-as-library -module-name HandyApp -target arm64-apple-macos14.0 -sdk "$SDK" \
  -I "$BIN/Modules" -I "$BIN" -F "$BIN" \
  -emit-const-values-path "$WORK/HandyApp.swiftconstvalues" \
  -Xfrontend -const-gather-protocols-file -Xfrontend "$WORK/protocols.json" \
  -c $(cat "$WORK/sources.txt") -o "$WORK/HandyApp.o"
echo "$WORK/HandyApp.swiftconstvalues" > "$WORK/constvalues.txt"
xcrun appintentsmetadataprocessor --output "$APP/Contents/Resources" --toolchain-dir "$TOOLCHAIN" \
  --module-name HandyApp --sdk-root "$SDK" --xcode-version "$XCODE_BUILD" --platform-family macOS \
  --deployment-target 14.0 --target-triple arm64-apple-macos14.0 \
  --source-file-list "$WORK/sources.txt" --swift-const-vals-list "$WORK/constvalues.txt" --quiet-warnings
test -d "$APP/Contents/Resources/Metadata.appintents"
