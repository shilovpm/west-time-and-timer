#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/build/local/WEST time and timer.app"
OUT="$PWD/dist/WEST-time-and-timer-local-arm64.dmg"
STAGE="$PWD/build/dmg"
scripts/build-xcode-local.sh
rm -rf "$STAGE" "$OUT"
mkdir -p "$STAGE" "$PWD/dist"
ditto "$APP" "$STAGE/WEST time and timer.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "WEST time and timer" -srcfolder "$STAGE" -format UDZO "$OUT"
(cd "$PWD/dist" && shasum -a 256 "$(basename "$OUT")" > "$(basename "$OUT").sha256")
printf 'Local DMG: %s\n' "$OUT"
