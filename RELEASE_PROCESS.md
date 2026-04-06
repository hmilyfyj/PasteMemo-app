# PasteMemo 发版流程文档

## 📋 概述

PasteMemo 使用手动发版流程，通过 Sparkle 框架实现自动更新功能。本文档详细说明了如何发布新版本。

## 🚀 发版流程

### 1. 准备工作

#### 1.1 确保代码已提交

```bash
git status
git add .
git commit -m "chore: prepare for release vX.X.X"
git push
```

#### 1.2 更新版本号

编辑 `scripts/rebuild_and_open.sh`，更新以下字段：

```bash
<key>CFBundleShortVersionString</key>
<string>X.X.X</string>  # 用户可见的版本号
<key>CFBundleVersion</key>
<string>XXX</string>     # 构建号（递增）
```

### 2. 构建应用

#### 2.1 构建 Release 版本

```bash
swift build -c release
```

#### 2.2 创建应用包

```bash
./scripts/rebuild_and_open_stable.sh
```

这个脚本会：
- 构建应用
- 创建 .app 包
- 复制 Sparkle.framework
- 配置 rpath
- 签名应用
- 安装到 /Applications

### 3. 创建 DMG 文件

#### 3.1 创建临时目录

```bash
cd /tmp
rm -rf PasteMemo-X.X.X.dmg PasteMemo-dmg
mkdir -p PasteMemo-dmg
```

#### 3.2 复制应用到临时目录

```bash
cp -R /Applications/PasteMemo.app PasteMemo-dmg/
```

#### 3.3 创建 DMG

```bash
hdiutil create -volname "PasteMemo" -srcfolder PasteMemo-dmg -ov -format UDZO PasteMemo-X.X.X.dmg
```

### 4. 签名 DMG

使用 Sparkle 工具签名：

```bash
.build/artifacts/sparkle/Sparkle/bin/sign_update /tmp/PasteMemo-X.X.X.dmg
```

输出示例：
```
sparkle:edSignature="..." length="..."
```

**重要**：保存输出的签名和文件大小，稍后需要用到！

### 5. 创建 Git Tag 和 GitHub Release

#### 5.1 创建 Git Tag

```bash
git tag -a vX.X.X -m "Release vX.X.X: 更新说明"
git push origin vX.X.X
```

#### 5.2 创建 GitHub Release

```bash
gh release create vX.X.X \
  --title "vX.X.X - 版本标题" \
  --notes "## 🎉 新功能

### 功能列表
- 功能1
- 功能2

## 📝 技术改进
- 改进1
- 改进2

**完整更新日志**: https://github.com/hmilyfyj/PasteMemo-app/compare/v旧版本...vX.X.X"
```

### 6. 上传 DMG 到 GitHub Release

```bash
gh release upload vX.X.X /tmp/PasteMemo-X.X.X.dmg
```

### 7. 更新 appcast.xml

#### 7.1 编辑 appcast.xml

在 `<channel>` 标签内的最前面添加新的 `<item>`：

```xml
<item>
    <title>Version X.X.X</title>
    <pubDate>发布日期（格式：Sun, 06 Apr 2026 21:25:00 +0800）</pubDate>
    <sparkle:version>XXX</sparkle:version>
    <sparkle:shortVersionString>X.X.X</sparkle:shortVersionString>
    <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
    <description><![CDATA[
        <h2>版本标题</h2>
        <h3>🎉 新功能</h3>
        <ul>
            <li>功能1</li>
            <li>功能2</li>
        </ul>
    ]]></description>
    <enclosure
        url="https://github.com/hmilyfyj/PasteMemo-app/releases/download/vX.X.X/PasteMemo-X.X.X.dmg"
        sparkle:edSignature="步骤4中获取的签名"
        length="步骤4中获取的文件大小"
        type="application/octet-stream"
    />
</item>
```

#### 7.2 提交 appcast.xml

```bash
git add appcast.xml
git commit -m "chore: update appcast.xml for vX.X.X release"
git push
```

### 8. 验证发布

#### 8.1 检查 GitHub Release

访问：https://github.com/hmilyfyj/PasteMemo-app/releases/tag/vX.X.X

确认：
- ✅ Release 已创建
- ✅ DMG 文件已上传
- ✅ Release notes 正确

#### 8.2 检查 appcast.xml

```bash
curl -I https://raw.githubusercontent.com/hmilyfyj/PasteMemo-app/main/appcast.xml
```

应该返回 HTTP 200。

#### 8.3 测试自动更新

1. 打开应用
2. 检查应用是否能检测到新版本
3. 测试下载和安装流程

## 📝 快速发版脚本

### 完整发版脚本

创建 `scripts/release.sh`：

```bash
#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.3.1"
    exit 1
fi

VERSION=$1
BUILD_NUMBER=$(echo $VERSION | tr -d '.')
DMG_NAME="PasteMemo-${VERSION}.dmg"

echo "==> 开始发布 v${VERSION}"

# 1. 构建应用
echo "==> 构建应用"
swift build -c release

# 2. 创建应用包
echo "==> 创建应用包"
./scripts/rebuild_and_open_stable.sh

# 3. 创建 DMG
echo "==> 创建 DMG"
cd /tmp
rm -rf ${DMG_NAME} PasteMemo-dmg
mkdir -p PasteMemo-dmg
cp -R /Applications/PasteMemo.app PasteMemo-dmg/
hdiutil create -volname "PasteMemo" -srcfolder PasteMemo-dmg -ov -format UDZO ${DMG_NAME}

# 4. 签名 DMG
echo "==> 签名 DMG"
cd /Users/fengit/workspace/PasteMemo-app
SIGNATURE=$(.build/artifacts/sparkle/Sparkle/bin/sign_update /tmp/${DMG_NAME})
echo "签名信息："
echo "${SIGNATURE}"

# 5. 创建 Tag
echo "==> 创建 Git Tag"
git tag -a v${VERSION} -m "Release v${VERSION}"
git push origin v${VERSION}

# 6. 创建 GitHub Release
echo "==> 创建 GitHub Release"
gh release create v${VERSION} \
  --title "v${VERSION}" \
  --notes "## 🎉 新功能

请手动编辑 Release notes

**完整更新日志**: https://github.com/hmilyfyj/PasteMemo-app/compare/v旧版本...v${VERSION}"

# 7. 上传 DMG
echo "==> 上传 DMG"
gh release upload v${VERSION} /tmp/${DMG_NAME}

echo "==> 发布完成！"
echo "请手动更新 appcast.xml"
echo "签名信息：${SIGNATURE}"
```

使用方法：

```bash
chmod +x scripts/release.sh
./scripts/release.sh 1.3.1
```

## ⚠️ 注意事项

### 1. 版本号规范

- **CFBundleShortVersionString**：用户可见的版本号，格式：`X.X.X`
- **CFBundleVersion**：构建号，必须递增，格式：`XXX`（去掉点号）

### 2. 签名安全

- **私钥**：保存在系统 keychain 中，不要泄露
- **公钥**：配置在 Info.plist 中，可以公开

### 3. appcast.xml 格式

- 必须包含正确的 EdDSA 签名
- `length` 必须是准确的文件大小（字节）
- 新版本的 `<item>` 必须放在最前面

### 4. GitHub Release

- Release 创建后，DMG 文件可能需要几分钟才能访问
- 确保 DMG 文件名与 appcast.xml 中的 URL 匹配

### 5. 测试流程

发布后务必测试：
1. 新用户安装
2. 老用户更新
3. 自动更新检测
4. 手动更新检查

## 🔧 故障排除

### 问题1：DMG 无法下载

**原因**：GitHub Release CDN 缓存延迟

**解决**：等待 5-10 分钟后重试

### 问题2：签名验证失败

**原因**：公钥与私钥不匹配

**解决**：
1. 检查 Info.plist 中的 `SUPublicEDKey`
2. 确认使用正确的私钥签名
3. 重新生成密钥对（最后手段）

### 问题3：应用无法检测到更新

**原因**：appcast.xml 未更新或格式错误

**解决**：
1. 检查 appcast.xml 是否已提交
2. 验证 XML 格式是否正确
3. 确认版本号高于当前版本

## 📚 相关文档

- [Sparkle 官方文档](https://sparkle-project.org/documentation/)
- [Sparkle 集成说明](./SPARKLE_INTEGRATION.md)
- [密钥管理](./SPARKLE_KEYS.md)

## 🎯 最佳实践

1. **发布前测试**：在本地充分测试所有功能
2. **版本号递增**：确保版本号和构建号都递增
3. **详细说明**：提供清晰的 Release notes
4. **备份签名**：保存每次发布的签名信息
5. **监控反馈**：关注用户反馈，及时修复问题

---

**最后更新**：2026-04-06
