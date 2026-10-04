# Quality Guidelines

> 用仓库里已有的 Makefile 和脚本做验证。

## 命令

| 目的 | 命令 |
|------|------|
| 单测 | `make test`（`swift test`） |
| 全仓检查 | `make check`（`bash ./scripts/check.sh --all`） |
| 仅暂存文件 | `make check-staged` |
| 本地开发构建并打开 | `./scripts/rebuild_and_open.sh` |
| 本机稳定安装（ARM） | `./scripts/rebuild_and_open_stable.sh` |

`rebuild_and_open.sh` 默认把 debug 包打到 `.dist/PasteMemo.app`。`rebuild_and_open_stable.sh` 会装到 `/Applications/PasteMemo.app`，给本机日常使用。

## 测试

- 可测逻辑补 `Tests/` 里已有风格的 XCTest 文件，例如 `Tests/CodeDetectorTests.swift`、`Tests/RuleConditionTests.swift`
- 只改文档 / Trellis 脚手架时，不必重装应用

## 禁止

- 提交 `sparkle_private_key.pem`
- 把 `.build/`、`.dist/`、`.swiftpm/` 加进版本库
- 在没有测试或 `make check` 的情况下改 Engine 规则/解析逻辑
