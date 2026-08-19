# FEATURE-347 修复悬浮框打开崩溃

## 目标

打开底部悬浮框不再把应用打崩；热键能稳定弹出面板。

## 背景 / 已知事实

- 用户反馈「打不开、弹不出来悬浮框」。本机无进程，有两份 1.8.0 (1800) 崩溃：`09:36:29`、`09:44:12`。
- 崩溃类型 `EXC_BAD_ACCESS` / `swift_beginAccess`，栈在 `-[NSView _layoutSubtreeWithOldSize:]`，发生在面板弹出后约 1 分钟的布局刷新。
- `bottomClipRail` 用 `GeometryReader` 包住横向 `LazyHStack`。用户历史约 3 万条，GeometryReader 在每次布局回调里改卡片宽高，触发 Swift 独占访问 + AppKit 布局循环。
- 两次崩溃都发生在今天 09:35 装上 compact-preview 之后。

## 需求要点

- 去掉卡片轨道里的 GeometryReader。
- 卡片高度改从窗口 `layoutState.height` 推算（搜索/底栏预留固定 chrome）。
- 打开面板后应用保持存活，热键能再次弹出。

## 范围外

- 不改经典面板。
- 不推上游。

## 验收标准

- [x] `swift build` 通过。
- [x] 启动 `/Applications/PasteMemo.app` 后进程仍在。
- [x] 打开底部悬浮框后至少 30 秒不出现新的 PasteMemo crash report。
