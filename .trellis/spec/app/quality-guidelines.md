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

## 悬浮卡片鼠标滚轮

- `HorizontalMouseWheelScrollBridge` 只挂在底部卡片 `LazyHStack` 的 background，标记视图不参与点击命中。
- 只转换命中该原生滚动容器的纯竖向事件；已有横向/斜向手势、预览区和浮层里的其他滚动容器保持原生处理。
- 普通滚轮距离乘 `NSScrollView.horizontalLineScroll`；精确竖向事件按像素距离处理，兼容 Mos 平滑鼠标滚轮和连续惯性事件。
- 通过 `NSClipView.constrainBoundsRect` 限制左右边界，再 `scroll(to:)` 和 `reflectScrolledClipView`；隐藏/卸载时不处理事件，卸载必须移除局部监听。
- `HorizontalMouseWheelScrollTests` 验证两种距离单位、方向和边界、短内容透传，以及真实 SwiftUI 容器挂载和滚动。

## 禁止

- 提交 `sparkle_private_key.pem`
- 把 `.build/`、`.dist/`、`.swiftpm/` 加进版本库
- 在没有测试或 `make check` 的情况下改 Engine 规则/解析逻辑
