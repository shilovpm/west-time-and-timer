#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

DERIVED="$PWD/build/XcodeDerivedData"
PRODUCT="$DERIVED/Build/Products/Release/WEST time and timer.app"
APP="$PWD/build/local/WEST time and timer.app"
EXTENSION="$PRODUCT/Contents/PlugIns/WESTWidgets.appex"
ENTITLEMENTS="$PWD/Config/Local-AdHoc.entitlements"

command -v xcodebuild >/dev/null
xcrun --find appintentsmetadataprocessor >/dev/null

xcodebuild -project WEST.xcodeproj -scheme WEST -configuration Release \
  -derivedDataPath "$DERIVED" clean build CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES

test -f "$EXTENSION/Contents/Resources/Metadata.appintents/extract.actionsdata"
test -f "$PRODUCT/Contents/Resources/Metadata.appintents/extract.actionsdata"
grep -q 'ClockConfiguration' "$EXTENSION/Contents/Resources/Metadata.appintents/extract.actionsdata"
! grep -q 'SavedClockEntity' "$PRODUCT/Contents/Resources/Metadata.appintents/extract.actionsdata"
! grep -q 'SavedClockEntity' "$EXTENSION/Contents/Resources/Metadata.appintents/extract.actionsdata"
test -f "$PRODUCT/Contents/Resources/AppIcon.icns"
test -f "$EXTENSION/Contents/Resources/AppIcon.icns"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$PRODUCT/Contents/Info.plist")" = "AppIcon"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$EXTENSION/Contents/Info.plist")" = "AppIcon.icns"
codesign --force --sign - --timestamp=none --options runtime --entitlements "$ENTITLEMENTS" "$EXTENSION"
codesign --force --sign - --timestamp=none --options runtime --entitlements "$ENTITLEMENTS" "$PRODUCT"
codesign --verify --deep --strict "$PRODUCT"

rm -rf "$APP"
mkdir -p "$(dirname "$APP")"
ditto "$PRODUCT" "$APP"
# xcodebuild registers intermediate products as apps. Keeping those duplicate
# registrations can make URL dispatch and notification icons resolve against
# a build artifact instead of the installed copy.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -u "$PRODUCT" >/dev/null 2>&1 || true
"$LSREGISTER" -u "$APP" >/dev/null 2>&1 || true
printf 'Local Xcode app: %s\n' "$APP"
printf 'Widget mode: WidgetKit with App Intents metadata and local shared storage.\n'
