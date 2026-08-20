#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
BUILD_DIR="$PROJECT_DIR/.build/test-runners"
MODULE_CACHE="$PROJECT_DIR/.build/module-cache"

mkdir -p "$BUILD_DIR" "$MODULE_CACHE"
if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
fi

COMMON=(
  "$PROJECT_DIR/Sources/CleanSweep/Models.swift"
  "$PROJECT_DIR/Sources/CleanSweep/CleanupScanner.swift"
  "$PROJECT_DIR/Tests/Support/TestSupport.swift"
)

swiftc -parse-as-library -module-cache-path "$MODULE_CACHE" \
  "${COMMON[@]}" "$PROJECT_DIR/Tests/Unit/UnitTestRunner.swift" \
  -o "$BUILD_DIR/unit-tests"
"$BUILD_DIR/unit-tests"

swiftc -parse-as-library -module-cache-path "$MODULE_CACHE" \
  "${COMMON[@]}" "$PROJECT_DIR/Sources/CleanSweep/CleanupExecutor.swift" \
  "$PROJECT_DIR/Tests/Integration/IntegrationTestRunner.swift" \
  -o "$BUILD_DIR/integration-tests"
"$BUILD_DIR/integration-tests"
