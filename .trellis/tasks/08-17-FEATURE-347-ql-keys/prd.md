# FEATURE-347 预览打开后空格关闭且左右切卡片

## 目标

空格打开 Quick Look 后，再按空格关掉预览；左右键继续切换底部悬浮卡片并刷新预览。

## 背景 / 已知事实

- 用户反馈：空格唤出预览后，空格关不掉，左右也不能切卡片。
- 当前 `QuickLookHelper` 用 `orderFront` + 一次 `restoreKey`。QL 会在下一轮 run loop 再抢 key，按键落到预览窗。
- `isPreviewVisible` 只看 `QLPreviewPanel.isVisible`，`orderFront` 后这个值不可靠，`toggle` 可能一直走打开而不是关闭。
- 1.3.23 用本地/全局 key monitor 拦截空格/Esc，并用延迟 `reclaimPanelFocus` 把焦点拉回悬浮框。

## 需求要点

- 自己记一份预览打开状态，空格在打开时关闭。
- QL 打开期间拦截空格/Esc 关闭，拦截左右键切卡片并刷新预览。
- 打开后延迟把 key 拉回悬浮框。
- 悬浮框保持显示。

## 范围外

- 不改经典面板 ⌘O。
- 不推上游。

## 验收标准

- [ ] 空格打开预览后再按空格，预览关掉，悬浮框还在。
- [ ] 预览打开时按左右，选中卡片和预览一起变。
- [ ] `swift build` 通过并重装本机应用。
