#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_DIR="$PROJECT_DIR/build/Pomo.app"
CACHE_DIR="$PROJECT_DIR/.build/clang-module-cache"
ICONSET_DIR="$PROJECT_DIR/.build/Pomo.iconset"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$CACHE_DIR"

CLANG_MODULE_CACHE_PATH="$CACHE_DIR" /usr/bin/xcrun swiftc \
  -O \
  -parse-as-library \
  -target arm64-apple-macosx14.0 \
  "$PROJECT_DIR"/Sources/Pomo/*.swift \
  -o "$APP_DIR/Contents/MacOS/Pomo"

CLANG_MODULE_CACHE_PATH="$CACHE_DIR" /usr/bin/xcrun swiftc \
  -target arm64-apple-macosx14.0 \
  "$PROJECT_DIR/scripts/generate_tomato_icon.swift" \
  -o "$PROJECT_DIR/.build/generate-tomato-icon"
"$PROJECT_DIR/.build/generate-tomato-icon" "$PROJECT_DIR/Assets/AppIcon-1024.png"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
for spec in "16 icon_16x16" "32 icon_16x16@2x" "32 icon_32x32" "64 icon_32x32@2x" "128 icon_128x128" "256 icon_128x128@2x" "256 icon_256x256" "512 icon_256x256@2x" "512 icon_512x512" "1024 icon_512x512@2x"; do
  size="${spec%% *}"
  name="${spec#* }"
  /usr/bin/sips -z "$size" "$size" "$PROJECT_DIR/Assets/AppIcon-1024.png" --out "$ICONSET_DIR/$name.png" >/dev/null
done
python3 "$PROJECT_DIR/scripts/pack_icns.py" "$ICONSET_DIR" "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Pomo</string>
    <key>CFBundleIdentifier</key>
    <string>local.pomo.timer</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleName</key>
    <string>Pomo</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
</dict>
</plist>
PLIST

chmod +x "$APP_DIR/Contents/MacOS/Pomo"
/usr/bin/codesign --force --sign - "$APP_DIR" >/dev/null
echo "Built $APP_DIR"
