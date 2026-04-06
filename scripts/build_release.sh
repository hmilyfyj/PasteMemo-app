#!/bin/zsh
set -e

ROOT_DIR="/Users/fengit/workspace/PasteMemo-app"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/release"
DIST_DIR="$ROOT_DIR/.dist"
APP_DIR="$DIST_DIR/PasteMemo.app"
VERSION="1.2.2"

echo "==> 创建应用包结构"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

echo "==> 复制可执行文件"
cp "$BUILD_DIR/PasteMemo" "$APP_DIR/Contents/MacOS/PasteMemo"

echo "==> 复制资源包"
cp -R "$BUILD_DIR/PasteMemo_PasteMemo.bundle" "$APP_DIR/Contents/Resources/"

echo "==> 复制图标"
if [[ -f "$BUILD_DIR/PasteMemo_PasteMemo.bundle/Resources/AppIcon.icns" ]]; then
  cp "$BUILD_DIR/PasteMemo_PasteMemo.bundle/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"
fi

echo "==> 创建 Info.plist"
cat > "$APP_DIR/Contents/Info.plist" <<EOF
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
    <string>com.lifedever.PasteMemo</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>PasteMemo</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "==> 签名应用"
codesign --force --deep --sign - "$APP_DIR"

echo "==> 创建 DMG"
DMG_PATH="$DIST_DIR/PasteMemo-$VERSION-arm64.dmg"
rm -f "$DMG_PATH"
hdiutil create -volname "PasteMemo" -srcfolder "$APP_DIR" -ov -format UDZO "$DMG_PATH"

echo "==> 完成!"
echo "DMG 路径: $DMG_PATH"
ls -lh "$DMG_PATH"
