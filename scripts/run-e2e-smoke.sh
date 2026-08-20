#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP="$PROJECT_DIR/dist/CleanSweep.app"

"$PROJECT_DIR/scripts/build-app.sh"
test -x "$APP/Contents/MacOS/CleanSweep"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" = "com.shouvik.cleansweep"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundlePackageType' "$APP/Contents/Info.plist")" = "APPL"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP/Contents/Info.plist")" = "CleanSweep.icns"
test -f "$APP/Contents/Resources/CleanSweep.icns"
test -f "$APP/Contents/Resources/CleanSweepLight.png"
test -f "$APP/Contents/Resources/CleanSweepDark.png"
test -f "$APP/Contents/Resources/CleanSweepTinted.png"
codesign --verify --deep --strict "$APP"
file "$APP/Contents/MacOS/CleanSweep" | grep -q 'Mach-O 64-bit executable'

echo "✓ End-to-end smoke: packaged app structure, metadata, architecture, and signature passed"
