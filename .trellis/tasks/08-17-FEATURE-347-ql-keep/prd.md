# FEATURE-347 空格预览时悬浮框不消失

## 目标

底部悬浮里按空格打开 Quick Look 后，悬浮框保持显示，焦点仍在卡片上，左右键能继续切换并刷新预览。

## 背景 / 已知事实

- 空格在搜索为空时调用 `QuickLookHelper.toggle`，内部 `QLPreviewPanel.makeKeyAndOrderFront`。
- `QuickPanelWindowController` 监听 `didResignKey` 和全局鼠标按下，默认会 `dismiss()`。
- 已有 `suppressDismiss` 开关，当前预览路径没有打开它。
- 用户期望预览框和悬浮框同时在，并能左右切卡片。

## 需求要点

- 打开 QL 前打开 `suppressDismiss`，关闭 QL 后关掉。
- QL 用 `orderFront` 而不是 `makeKeyAndOrderFront`，随后把 key 交回悬浮框。
- 左右切卡片时，若 QL 已打开则刷新为当前卡片。
- 关掉悬浮框时一并关掉 QL。

## 范围外

- 不改经典面板的 ⌘O 预览策略。
- 不推上游。

## 验收标准

- [ ] 空格打开预览后悬浮框仍在。
- [ ] 预览打开时按左右，选中卡片和预览内容一起变。
- [ ] 再按空格或关悬浮框，预览会关掉。
- [ ] `swift build` 通过并重装本机应用。
