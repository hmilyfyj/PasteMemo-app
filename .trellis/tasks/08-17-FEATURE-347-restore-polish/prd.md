# FEATURE-347 接回合并前悬浮框优化

## 目标

把 1.3.23 底部悬浮框里用户能立刻感知的卡片视觉和打字搜索接回 1.8.0，面板打开后观感接近合并前。

## 背景 / 已知事实

- 合并策略是以上游 v1.8.0 为基线回放定制，当时只接回了底部悬浮骨架，没有整包搬 1.3.23 的 QuickPanel 拆分文件。
- 旧仓 `dd8ec06` 有 `QuickClipCard.swift` 663 行、`CardColorCache.swift`、`SearchHighlight.swift`、`bottomHeader`、打字即搜、来源 App 图标、搜索高亮。
- 当前 `origin/main` 的 `QuickClipCard.swift` 约 110 行，`searchText` 参数未使用；键盘监视器没有字母/数字自动进搜索。
- 旧版 GeometryReader + 实时缩放 AppKit 图层曾在 1.8.0 上导致启动/弹窗崩溃，本轮不接回。

## 需求要点

- 卡片恢复来源图标、类型化预览、页脚元信息、搜索高亮。
- 未聚焦搜索时输入字母/数字，自动写入搜索框并关闭 Quick Look。
- 右键卡片先选中再出菜单。
- 保留现有满宽、底栏固定、空格预览不关面板、无标题栏防崩。

## 范围外

- 不接回 GeometryReader 量高、AppKit 实时缩放轨道、底部滑出动画。
- 不重做旧版独立 `bottomHeader` / `compactFooterBar`。
- 不推上游。

## 验收标准

- [ ] 底部悬浮卡片能看到来源 App 图标、文件/链接/颜色各自版式，搜索词有高亮。
- [ ] 焦点不在搜索框时按字母会进搜索。
- [ ] `swift build` 通过并重装本机应用。
