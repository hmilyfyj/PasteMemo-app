# 设计

## 边界

- 只动悬浮卡片、主题 token、搜索高亮、键盘打字搜。
- 窗口控制器、无标题栏、warm-up 跳过卡片渲染保持现状。

## 方案

1. 从 `dd8ec06` 回放 `QuickClipCard`、`CardColorCache`、`HighlightedText`。
2. `CardColorCache` 用 `item.itemID` 做缓存键，避开 SwiftData `id` 语义差异。
3. 主题补 `previewBackground` / `secondaryText` / `tertiaryText`。
4. 键盘监视器在无 ⌘、搜索未聚焦时拦截字母数字。
5. 卡片用现有 `onRightClick` 选中。

## 回滚

只回滚本分支 PR。不碰上游。
