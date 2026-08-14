#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-$(git -C "$ROOT_DIR" tag --list 'v*' --sort=-version:refname | sed -n '1s/^v//p')}"
BUILD_NUMBER="${VERSION//./}"
APP_DIR="$ROOT_DIR/.dist/release/PasteMemo.app"
DMG_PATH="$ROOT_DIR/.dist/PasteMemo-${VERSION}-arm64.dmg"

cd "$ROOT_DIR"

echo "==> 创建 Release 应用包"
PASTEMEMO_VERSION="$VERSION" \
PASTEMEMO_BUILD_NUMBER="$BUILD_NUMBER" \
PASTEMEMO_BUILD_CONFIGURATION="release" \
PASTEMEMO_APP_DIR="$APP_DIR" \
PASTEMEMO_OPEN_APP="0" \
PASTEMEMO_KILL_EXISTING="0" \
./scripts/rebuild_and_open.sh

echo "==> 创建 DMG"
rm -f "$DMG_PATH"
TMP_DIR="$(mktemp -d /tmp/pastememo-release.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT
mkdir -p "$TMP_DIR/PasteMemo-dmg"
cp -R "$APP_DIR" "$TMP_DIR/PasteMemo-dmg/"
hdiutil create -volname "PasteMemo" -srcfolder "$TMP_DIR/PasteMemo-dmg" -ov -format UDZO "$DMG_PATH"

echo "==> 完成!"
echo "应用路径: $APP_DIR"
echo "DMG 路径: $DMG_PATH"
