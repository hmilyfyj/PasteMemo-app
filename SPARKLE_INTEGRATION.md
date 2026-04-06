# Sparkle 自动更新集成说明

## 概述

PasteMemo 现在使用 [Sparkle](https://sparkle-project.org/) 框架进行自动更新，这是一个成熟、安全且广泛使用的 macOS 应用更新框架。

## 为什么选择 Sparkle？

### 优势

1. **安全性** ✅
   - 支持 EdDSA 签名验证
   - 支持 Apple Code Signing
   - 防止中间人攻击

2. **可靠性** ✅
   - 成熟稳定的框架
   - 广泛使用和测试
   - 自动处理各种边缘情况

3. **用户体验** ✅
   - 原生 macOS 更新体验
   - 自动后台更新
   - 增量更新（Delta Updates）支持

4. **开发者友好** ✅
   - 自动生成 appcast 文件
   - GitHub Actions 集成
   - 详细的文档和社区支持

## 架构变更

### 之前（自定义方案）

```
UpdateChecker.swift
├── GitHub Releases API 集成
├── 手动下载和安装
├── 自定义 UI 对话框
└── 定期检查逻辑
```

### 现在（Sparkle）

```
SparkleUpdater.swift
├── SPUStandardUpdaterController
├── appcast.xml RSS feed
├── Sparkle 内置 UI
└── 自动更新管理
```

## 文件结构

```
PasteMemo-app/
├── Sources/
│   ├── Engine/
│   │   ├── SparkleUpdater.swift       # Sparkle 更新控制器
│   │   └── UpdateChecker.swift        # 已弃用（保留用于参考）
│   └── Resources/
│       └── Info.plist                 # 包含 SUFeedURL 配置
├── appcast.xml                        # 更新 feed 文件
└── .github/
    └── workflows/
        └── release.yml                # 自动生成 appcast
```

## 配置说明

### 1. Info.plist

在 `Sources/Resources/Info.plist` 中配置：

```xml
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/hmilyfyj/PasteMemo-app/main/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY_HERE</string>
```

### 2. appcast.xml

更新 feed 文件位于项目根目录，包含：
- 版本信息
- 下载链接
- 更新说明
- EdDSA 签名

### 3. GitHub Actions

`.github/workflows/release.yml` 自动处理：
- 构建 DMG 文件
- 生成 EdDSA 签名
- 更新 appcast.xml
- 上传到 GitHub Releases

## 发布流程

### 自动发布（推荐）

1. 在 GitHub 上创建新的 Release
2. GitHub Actions 自动执行：
   - 构建应用
   - 创建 DMG
   - 生成签名
   - 更新 appcast.xml
   - 上传文件

### 手动发布

1. 构建应用：
   ```bash
   swift build -c release
   ```

2. 创建 DMG：
   ```bash
   create-dmg --volname "PasteMemo" PasteMemo.dmg .build/release/
   ```

3. 签名：
   ```bash
   ./Sparkle/bin/sign_update PasteMemo.dmg
   ```

4. 更新 appcast.xml：
   ```bash
   ./Sparkle/bin/generate_appcast .
   ```

5. 上传到 GitHub Releases

## EdDSA 密钥管理

### 生成密钥对

```bash
# 生成私钥
openssl genpkey -algorithm ED25519 -out sparkle_private_key.pem

# 提取公钥
openssl pkey -in sparkle_private_key.pem -pubout -out sparkle_public_key.pem
```

### 存储密钥

- **私钥**：存储在 GitHub Secrets（`SPARKLE_PRIVATE_KEY`）
- **公钥**：添加到 `Info.plist` 的 `SUPublicEDKey`

⚠️ **重要**：私钥必须保密，不要提交到代码库！

## 用户更新体验

1. **自动检查**：应用启动后自动检查更新
2. **后台下载**：更新在后台静默下载
3. **用户提示**：下载完成后提示用户安装
4. **一键安装**：用户确认后自动安装并重启

## 开发者注意事项

### 测试更新

在开发环境中测试更新：

1. 修改 `SUFeedURL` 指向测试 feed
2. 使用本地服务器托管 appcast.xml
3. 检查更新日志和签名

### 调试

查看 Sparkle 日志：

```bash
log stream --predicate 'process == "PasteMemo"' --level debug
```

### 常见问题

**Q: 更新检查失败？**
- 检查 `SUFeedURL` 是否正确
- 验证 appcast.xml 格式
- 确认 HTTPS 证书有效

**Q: 签名验证失败？**
- 确认公钥正确配置
- 检查私钥是否匹配
- 验证签名算法

**Q: 用户没有收到更新？**
- 检查版本号是否高于当前版本
- 确认 appcast.xml 已更新
- 验证下载链接有效

## 迁移指南

从旧的 UpdateChecker 迁移：

1. ✅ 添加 Sparkle 依赖
2. ✅ 创建 SparkleUpdater 类
3. ✅ 配置 Info.plist
4. ✅ 创建 appcast.xml
5. ✅ 设置 GitHub Actions
6. ✅ 更新 UI 调用
7. ✅ 测试更新流程

## 相关资源

- [Sparkle 官方文档](https://sparkle-project.org/documentation/)
- [Sparkle GitHub](https://github.com/sparkle-project/Sparkle)
- [EdDSA 签名指南](https://sparkle-project.org/documentation/keys/)
- [Appcast 格式说明](https://sparkle-project.org/documentation/publishing/)

## 支持

如有问题，请：
1. 查看 [Sparkle 文档](https://sparkle-project.org/documentation/)
2. 搜索 [GitHub Issues](https://github.com/sparkle-project/Sparkle/issues)
3. 提交新 Issue

---

**更新日期**：2026-04-06  
**Sparkle 版本**：2.9.1
