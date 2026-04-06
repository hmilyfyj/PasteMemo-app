#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "用法: $0 <版本号>"
    echo "示例: $0 1.3.3"
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

# 1. 检查工作目录
echo "==> [1/10] 检查工作目录"
cd "$ROOT_DIR"
if [ -n "$(git status --porcelain)" ]; then
    echo "⚠️  警告：有未提交的更改"
    git status --short
    read -p "是否继续？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 2. 构建应用
echo ""
echo "==> [2/10] 构建 Release 版本"
swift build -c release

# 3. 创建应用包
echo ""
echo "==> [3/10] 创建应用包"
PASTEMEMO_VERSION="$VERSION" \
PASTEMEMO_BUILD_NUMBER="$BUILD_NUMBER" \
./scripts/rebuild_and_open_stable.sh

# 4. 创建 DMG
echo ""
echo "==> [4/10] 创建 DMG 文件"
cd /tmp
rm -rf ${DMG_NAME} PasteMemo-dmg
mkdir -p PasteMemo-dmg
cp -R /Applications/PasteMemo.app PasteMemo-dmg/
hdiutil create -volname "PasteMemo" -srcfolder PasteMemo-dmg -ov -format UDZO ${DMG_NAME}

# 5. 获取 DMG 信息
echo ""
echo "==> [5/10] 获取 DMG 文件信息"
DMG_SIZE=$(stat -f%z /tmp/${DMG_NAME})
echo "文件大小: ${DMG_SIZE} 字节"

# 6. 签名 DMG
echo ""
echo "==> [6/10] 使用 Sparkle 签名 DMG"
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

# 7. 创建 Git Tag
echo "==> [7/10] 创建 Git Tag"
read -p "请输入更新说明: " RELEASE_NOTES
git tag -a v${VERSION} -m "Release v${VERSION}: ${RELEASE_NOTES}"
git push origin v${VERSION}

# 8. 创建 GitHub Release
echo ""
echo "==> [8/10] 创建 GitHub Release"
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

# 9. 上传 DMG
echo ""
echo "==> [9/10] 上传 DMG 到 GitHub Release"
gh release upload v${VERSION} /tmp/${DMG_NAME}

# 10. 更新 appcast.xml
echo ""
echo "==> [10/10] 更新 appcast.xml"

# 使用 Python 脚本更新 appcast.xml
python3 scripts/update_appcast.py \
  "${VERSION}" \
  "${BUILD_NUMBER}" \
  "${SIGNATURE}" \
  "${LENGTH}" \
  "${RELEASE_NOTES}" \
  "${DMG_NAME}"

echo "✅ appcast.xml 已更新"

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
