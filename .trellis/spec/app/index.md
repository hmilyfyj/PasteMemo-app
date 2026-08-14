# App Development Guidelines

> PasteMemo 是 Swift 6 SPM 的 macOS 14+ 剪贴板应用。本目录记录已在仓库里验证过的约定。

## 何时使用

改 `Sources/`、`Tests/`、`scripts/`、`Package.swift` 或本地构建脚本前先读这里。

## 指南索引

| 指南 | 说明 |
|------|------|
| [Directory Structure](./directory-structure.md) | 源码、测试、脚本目录 |
| [Quality Guidelines](./quality-guidelines.md) | 测试、check、本地安装 |
| [Fork and Release](./fork-and-release.md) | fork、上游合并、Sparkle 密钥 |

## 开发前检查

- [ ] 新代码放进已有 `Sources/` 分层，不新建平行顶层
- [ ] 可测逻辑补 `Tests/`
- [ ] 改完业务代码后跑 `make test` 或对应单测
- [ ] 需要本机验证时跑 `./scripts/rebuild_and_open_stable.sh`

## 质量检查

- [ ] `make check` 能过
- [ ] 没有把 `sparkle_private_key.pem` 加进提交
- [ ] 没有把改动推到 upstream
