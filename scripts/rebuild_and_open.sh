#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/debug"
DEFAULT_APP_DIR="$ROOT_DIR/.dist/PasteMemo.app"
APP_DIR="${PASTEMEMO_APP_DIR:-$DEFAULT_APP_DIR}"
APP_CONTENTS_DIR="$APP_DIR/Contents"
APP_BINARY="$BUILD_DIR/PasteMemo"
APP_BUNDLE="$BUILD_DIR/PasteMemo_PasteMemo.bundle"
APP_EXECUTABLE="$APP_CONTENTS_DIR/MacOS/PasteMemo"
APP_ICON="$APP_BUNDLE/Resources/AppIcon.icns"
BUNDLE_ID="${PASTEMEMO_BUNDLE_ID:-com.lifedever.PasteMemo.dev}"
SIGNING_IDENTITY="${PASTEMEMO_SIGNING_IDENTITY:-}"

if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(.*\)"/\1/p' | head -n 1 || true)"
fi

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
if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_DIR"
else
  echo "未找到可用代码签名证书，回退到 adhoc 签名"
  echo "提示: adhoc 签名会导致辅助功能权限在重建后经常失效"
  codesign --force --deep --sign - "$APP_DIR"
fi

echo "==> 关闭旧进程"
pkill -f "$APP_EXECUTABLE" 2>/dev/null || true

for _ in {1..20}; do
  if ! pgrep -f "$APP_EXECUTABLE" >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done

echo "==> 打开新应用"
if ! open -n "$APP_DIR"; then
  echo "open 失败，1 秒后重试"
  sleep 1
  if ! open -n "$APP_DIR"; then
    echo "LaunchServices 仍未响应，改为直接启动可执行文件"
    "$APP_EXECUTABLE" >/tmp/pastememo-launch.log 2>&1 &
    disown
  fi
fi

echo
echo "完成"
echo "应用路径: $APP_DIR"
echo "Bundle ID: $BUNDLE_ID"
if [[ -n "$SIGNING_IDENTITY" ]]; then
  echo "Signing Identity: $SIGNING_IDENTITY"
else
  echo "Signing Identity: adhoc"
fi
