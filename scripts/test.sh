#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/module-cache"
if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
fi

cd "$PROJECT_DIR"
swift build --disable-sandbox
"$PROJECT_DIR/scripts/run-swift-tests.sh"
for file in Sources/CleanSweep/*.swift; do
  swiftc -frontend -parse "$file" -module-cache-path "$PROJECT_DIR/.build/module-cache"
done
zsh -n scripts/build-app.sh
plutil -lint Resources/Info.plist
"$PROJECT_DIR/scripts/run-e2e-smoke.sh"
echo "All test-pyramid layers and static validation passed."
