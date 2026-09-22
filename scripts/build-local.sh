#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD="$PWD/build/local"
APP="$BUILD/WEST time and timer.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/PlugIns/WESTWidgets.appex/Contents/MacOS" "$APP/Contents/PlugIns/WESTWidgets.appex/Contents/Resources"
python3 scripts/local-resources.py "$APP" "$BUILD"
SDK="$(xcrun --show-sdk-path)"
ARCH="$(uname -m)"
swiftc -O -D LOCAL_WIDGET_STATIC -parse-as-library -sdk "$SDK" -target "$ARCH-apple-macos15.0" -module-cache-path "$BUILD/ModuleCache" -module-name WEST WEST/Shared/*.swift WEST/App/*.swift -o "$APP/Contents/MacOS/WEST"
swiftc -O -D LOCAL_WIDGET_STATIC -parse-as-library -sdk "$SDK" -target "$ARCH-apple-macos15.0" -module-cache-path "$BUILD/ModuleCache" -module-name WESTWidgets -application-extension WEST/Shared/*.swift WEST/Widgets/*.swift -o "$APP/Contents/PlugIns/WESTWidgets.appex/Contents/MacOS/WESTWidgets"
codesign --force --sign - --entitlements "$BUILD/local.entitlements" "$APP/Contents/PlugIns/WESTWidgets.appex"
codesign --force --sign - --entitlements "$BUILD/local.entitlements" "$APP"
codesign --verify --deep --strict "$APP"
printf 'Local app: %s\n' "$APP"
printf 'Local widget mode: static clock selection and deep-link timer controls (no App Intents metadata).\n'
