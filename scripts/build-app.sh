#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_NAME="CleanSweep"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_DIR="$PROJECT_DIR/dist/$APP_NAME.app"

export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/module-cache"
if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
fi

cd "$PROJECT_DIR"
"$PROJECT_DIR/scripts/generate-icon-assets.sh"
swift build --disable-sandbox -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/Icons/CleanSweep.icns" "$APP_DIR/Contents/Resources/CleanSweep.icns"
cp "$PROJECT_DIR/Resources/Icons/CleanSweepLight.png" "$APP_DIR/Contents/Resources/CleanSweepLight.png"
cp "$PROJECT_DIR/Resources/Icons/CleanSweepDark.png" "$APP_DIR/Contents/Resources/CleanSweepDark.png"
cp "$PROJECT_DIR/Resources/Icons/CleanSweepTinted.png" "$APP_DIR/Contents/Resources/CleanSweepTinted.png"
cp "$PROJECT_DIR/Resources/Icons/CleanSweepTemplate.png" "$APP_DIR/Contents/Resources/CleanSweepTemplate.png"
codesign --force --deep --sign - "$APP_DIR"

echo "Built $APP_DIR"
