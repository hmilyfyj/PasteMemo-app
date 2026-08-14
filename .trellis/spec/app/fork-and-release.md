# Fork and Release

> 本仓是上游的 fork，本地改进定期合入，不回推上游。

## 远端

- `origin`：`https://github.com/hmilyfyj/PasteMemo-app.git`，日常推送和 PR 都走这里
- 上游仓库：`lifedever/PasteMemo-app`。可以 fetch / merge，不要 `push` 到 upstream
- 主干分支：`main`。没有 `develop`

## 合并上游

1. fetch 上游 tag 或 `main` / `develop`
2. 在 fork 的 feature 分支上合并，保留 fork 自己的更新器和其他本地改动
3. PR 开向 `origin/main`

FEATURE-347 已经按这条路径合过 `upstream v1.8.0`。

## Sparkle

- 公钥：`sparkle_public_key.txt`（可提交）
- 私钥：`sparkle_private_key.pem`（已在 `.gitignore`）
- 更新说明见 `SPARKLE_INTEGRATION.md`、`SPARKLE_KEYS.md`、`RELEASE_PROCESS.md`
- `appcast.xml` 随发版更新

## 本机安装

构建好的 arm 应用装到本机。日常开发用 `./scripts/rebuild_and_open_stable.sh`。
