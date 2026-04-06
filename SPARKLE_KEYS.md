# Sparkle EdDSA Keys

## 🔑 密钥信息

**公钥 (SUPublicEDKey)**:
```
MCowBQYDK2VwAyEAwdQoLqridUWT9H+AR+Z8pZdMnUpV43w2iF7XAVDqwaI=
```

**私钥**:
```
-----BEGIN PRIVATE KEY-----
MC4CAQAwBQYDK2VwBCIEIGk5FPQAh93sOJJ8LuDxdWVRBKI7a7I7YeG1RBlLz4EN
-----END PRIVATE KEY-----
```

## 📝 配置步骤

### 1. GitHub Secrets 配置

在 GitHub 仓库中添加以下 Secret：

1. 进入仓库 Settings → Secrets and variables → Actions
2. 点击 "New repository secret"
3. 名称：`SPARKLE_PRIVATE_KEY`
4. 值：复制上面的完整私钥（包括 BEGIN 和 END 行）

### 2. 本地配置

公钥已经配置在：
- ✅ `scripts/rebuild_and_open.sh` 中的 Info.plist 模板
- ✅ `Sources/Resources/Info.plist` 文件

### 3. GitHub Actions 配置

`.github/workflows/release.yml` 已经配置好自动签名和发布流程。

## ⚠️ 安全警告

- **私钥绝对不要提交到代码库！**
- 私钥文件 `sparkle_private_key.pem` 已添加到 `.gitignore`
- 只有公钥可以公开，私钥必须保密

## 🔄 密钥轮换

如果需要重新生成密钥：

```bash
# 生成新的密钥对
openssl genpkey -algorithm ED25519 -out sparkle_private_key.pem
openssl pkey -in sparkle_private_key.pem -pubout -out sparkle_public_key.pem

# 提取公钥
grep -v "BEGIN\|END" sparkle_public_key.pem | tr -d '\n'
```

## 📚 相关文档

- [Sparkle Keys Documentation](https://sparkle-project.org/documentation/keys/)
- [EdDSA Signing Guide](https://sparkle-project.org/documentation/keys/)
