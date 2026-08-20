#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
BUILD_DIR="$PROJECT_DIR/.build/icon-generator"
RESOURCE_DIR="$PROJECT_DIR/Resources/Icons"
MODULE_CACHE="$PROJECT_DIR/.build/module-cache"

mkdir -p "$BUILD_DIR" "$MODULE_CACHE" "$RESOURCE_DIR"
if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
fi

swiftc -module-cache-path "$MODULE_CACHE" "$PROJECT_DIR/scripts/IconAssetGenerator.swift" -o "$BUILD_DIR/IconAssetGenerator"
"$BUILD_DIR/IconAssetGenerator" "$RESOURCE_DIR/CleanSweepTemplate.png" "$RESOURCE_DIR"
echo "Generated $RESOURCE_DIR/CleanSweep.icns"
