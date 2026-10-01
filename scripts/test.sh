#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
TESTING_FRAMEWORKS="$(/usr/bin/xcode-select -p)/Library/Developer/Frameworks"
TEST_FLAGS=()
if [[ -d "$TESTING_FRAMEWORKS/Testing.framework" ]]; then
  TEST_FLAGS=(-Xswiftc -F -Xswiftc "$TESTING_FRAMEWORKS" -Xlinker -rpath -Xlinker "$TESTING_FRAMEWORKS")
  TESTING_LIBS="${TESTING_FRAMEWORKS:h}/usr/lib"
  if [[ -f "$TESTING_LIBS/lib_TestingInterop.dylib" ]]; then
    TEST_FLAGS+=(-Xlinker -rpath -Xlinker "$TESTING_LIBS")
  fi
fi

CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/clang-module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/swift-module-cache" \
  /usr/bin/xcrun swift test \
    --package-path "$PROJECT_DIR" \
    --disable-sandbox --disable-xctest --enable-swift-testing \
    --cache-path "$PROJECT_DIR/.build/package-cache" \
    --config-path "$PROJECT_DIR/.build/config" \
    --security-path "$PROJECT_DIR/.build/security" \
    "${TEST_FLAGS[@]}" "$@"
