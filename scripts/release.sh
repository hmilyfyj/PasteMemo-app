#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "用法: $0 <版本号>"
    echo "示例: $0 1.3.1"
    exit 1
fi

VERSION=$1
BUILD_NUMBER=$(echo $VERSION | tr -d '.')
DMG_NAME="PasteMemo-${VERSION}.dmg"
ROOT_DIR="/Users/fengit/workspace/PasteMemo-app"

echo "=========================================="
echo "🚀 开始发布 v${VERSION}"
echo "=========================================="
echo ""

# 1. 构建应用
echo "==> [1/9] 构建 Release 版本"
cd "$ROOT_DIR"
swift build -c release

# 2. 创建应用包
echo ""
echo "==> [2/9] 创建应用包"
./scripts/rebuild_and_open_stable.sh

# 3. 创建 DMG
echo ""
echo "==> [3/9] 创建 DMG 文件"
cd /tmp
rm -rf ${DMG_NAME} PasteMemo-dmg
mkdir -p PasteMemo-dmg
cp -R /Applications/PasteMemo.app PasteMemo-dmg/
hdiutil create -volname "PasteMemo" -srcfolder PasteMemo-dmg -ov -format UDZO ${DMG_NAME}

# 4. 获取 DMG 信息
echo ""
echo "==> [4/9] 获取 DMG 文件信息"
DMG_SIZE=$(stat -f%z /tmp/${DMG_NAME})
echo "文件大小: ${DMG_SIZE} 字节"

# 5. 签名 DMG
echo ""
echo "==> [5/9] 使用 Sparkle 签名 DMG"
cd "$ROOT_DIR"
SIGNATURE_OUTPUT=$(.build/artifacts/sparkle/Sparkle/bin/sign_update /tmp/${DMG_NAME})
echo "签名信息："
echo "${SIGNATURE_OUTPUT}"
echo ""

# 提取签名和长度
SIGNATURE=$(echo "${SIGNATURE_OUTPUT}" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="//;s/"//')
LENGTH=$(echo "${SIGNATURE_OUTPUT}" | grep -o 'length="[^"]*"' | sed 's/length="//;s/"//')

echo "EdDSA 签名: ${SIGNATURE}"
echo "文件大小: ${LENGTH} 字节"
echo ""

# 6. 创建 Git Tag
echo "==> [6/9] 创建 Git Tag"
read -p "请输入更新说明: " RELEASE_NOTES
git tag -a v${VERSION} -m "Release v${VERSION}: ${RELEASE_NOTES}"
git push origin v${VERSION}

# 7. 创建 GitHub Release
echo ""
echo "==> [7/9] 创建 GitHub Release"
LATEST_TAG=$(git describe --tags --abbrev=0 HEAD~1 2>/dev/null || echo "v1.0.0")
gh release create v${VERSION} \
  --title "v${VERSION} - ${RELEASE_NOTES}" \
  --notes "## 🎉 新功能

### 更新内容
- ${RELEASE_NOTES}

## 📝 技术改进
- Sparkle 自动更新集成
- 性能优化

**完整更新日志**: https://github.com/hmilyfyj/PasteMemo-app/compare/${LATEST_TAG}...v${VERSION}"

# 8. 上传 DMG
echo ""
echo "==> [8/9] 上传 DMG 到 GitHub Release"
gh release upload v${VERSION} /tmp/${DMG_NAME}

# 9. 更新 appcast.xml
echo ""
echo "==> [9/9] 更新 appcast.xml"
echo ""
echo "请手动更新 appcast.xml，添加以下内容："
echo ""
echo "<item>"
echo "    <title>Version ${VERSION}</title>"
echo "    <pubDate>$(date '+%a, %d %b %Y %H:%M:%S %z')</pubDate>"
echo "    <sparkle:version>${BUILD_NUMBER}</sparkle:version>"
echo "    <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>"
echo "    <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>"
echo "    <description><![CDATA["
echo "        <h2>${RELEASE_NOTES}</h2>"
echo "        <h3>🎉 新功能</h3>"
echo "        <ul>"
echo "            <li>${RELEASE_NOTES}</li>"
echo "        </ul>"
echo "    ]]></description>"
echo "    <enclosure"
echo "        url=\"https://github.com/hmilyfyj/PasteMemo-app/releases/download/v${VERSION}/${DMG_NAME}\""
echo "        sparkle:edSignature=\"${SIGNATURE}\""
echo "        length=\"${LENGTH}\""
echo "        type=\"application/octet-stream\""
echo "    />"
echo "</item>"
echo ""

read -p "按回车键继续..."

# 提交 appcast.xml
git add appcast.xml
git commit -m "chore: update appcast.xml for v${VERSION} release"
git push

echo ""
echo "=========================================="
echo "🎉 发布完成！"
echo "=========================================="
echo ""
echo "版本: v${VERSION}"
echo "构建号: ${BUILD_NUMBER}"
echo "DMG 文件: ${DMG_NAME}"
echo "文件大小: ${LENGTH} 字节"
echo ""
echo "GitHub Release: https://github.com/hmilyfyj/PasteMemo-app/releases/tag/v${VERSION}"
echo "下载链接: https://github.com/hmilyfyj/PasteMemo-app/releases/download/v${VERSION}/${DMG_NAME}"
echo ""
