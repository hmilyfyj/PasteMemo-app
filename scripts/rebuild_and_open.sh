#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/debug"
APP_DIR="$ROOT_DIR/.dist/PasteMemo.app"
APP_CONTENTS_DIR="$APP_DIR/Contents"
APP_BINARY="$BUILD_DIR/PasteMemo"
APP_BUNDLE="$BUILD_DIR/PasteMemo_PasteMemo.bundle"
APP_EXECUTABLE="$APP_CONTENTS_DIR/MacOS/PasteMemo"
APP_ICON="$APP_BUNDLE/Resources/AppIcon.icns"
BUNDLE_ID="${PASTEMEMO_BUNDLE_ID:-com.lifedever.PasteMemo.dev}"

echo "==> 切换到项目目录"
cd "$ROOT_DIR"

echo "==> 开始 Swift 构建"
swift build

if [[ ! -f "$APP_BINARY" ]]; then
  echo "未找到构建产物: $APP_BINARY" >&2
  exit 1
fi

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "未找到资源包: $APP_BUNDLE" >&2
  exit 1
fi

echo "==> 重建应用包"
rm -rf "$APP_DIR"
mkdir -p "$APP_CONTENTS_DIR/MacOS" "$APP_CONTENTS_DIR/Resources"

cat > "$APP_CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>PasteMemo</string>
    <key>CFBundleExecutable</key>
    <string>PasteMemo</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>PasteMemo</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

cp "$APP_BINARY" "$APP_EXECUTABLE"
cp -R "$APP_BUNDLE" "$APP_CONTENTS_DIR/Resources/"

if [[ -f "$APP_ICON" ]]; then
  cp "$APP_ICON" "$APP_CONTENTS_DIR/Resources/AppIcon.icns"
fi

echo "==> 重新签名"
codesign --force --deep --sign - "$APP_DIR"

echo "==> 关闭旧进程"
pkill -f "$APP_EXECUTABLE" 2>/dev/null || true

echo "==> 打开新应用"
open "$APP_DIR"

echo
echo "完成"
echo "应用路径: $APP_DIR"
echo "Bundle ID: $BUNDLE_ID"
