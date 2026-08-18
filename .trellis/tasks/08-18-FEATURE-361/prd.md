# FEATURE-361 底部悬浮框去卡顿

## 目标

底部悬浮快捷面板在打开、左右切卡、触控板滑动时保持流畅，观感接近经典列表和 Paste，不再出现明显掉帧。

## 背景 / 已知事实

- 用户对比对象是经典列表样式和 Paste。经典列表走 `NativeClipHistoryList`（AppKit 复用行）；底部悬浮走 SwiftUI `LazyHStack` + `QuickClipCard`。
- `QuickPanelView.bottomClipRail` 对 `displayOrderItems` 做全量 `ForEach`。`ClipItemStore.pageSize` 初始 50，滑到末尾 `loadMore()` 后持续增长。注释仍按「3 万条轨道」防崩溃处理。
- 每张卡当前有：半径 10–18 的投影、hover `scaleEffect(1.02)`、选中弹簧动画、图标主线程取色（`CardColorCache.sampleCenterColor` 在 body 里同步画 36×36 bitmap）、`.interpolation(.high)`、每张卡都挂 `.popover`。
- 外壳 `quickPanelBottomShell()` 额外叠了一层 `blur(0.4)` 和半径 24 的 SwiftUI 阴影；窗口本身已是 `isOpaque = false` + `hasShadow = true` + `NSVisualEffectView`。
- `positionBottomFloating(..., animated:)` 打开时把窗口从下方滑入 0.22s。FEATURE-347 规划已写明不接回底部滑出动画，但这条动画仍在 `show()` 路径。
- 高度在 live resize 期间不回写（macOS 26 崩过）；本轮不能再引入 GeometryReader、不能在拖拽中发布卡片高度。

## 需求要点

- 打开底部悬浮框时窗口直接落到目标位置，不再边滑边排版卡片。
- 左右键切卡、触控板滑动时，卡片投影/缩放/弹簧不再带动整轨掉帧。
- 卡片仍保留类型色头图、来源图标、预览和选中描边，整体仍是底部卡片轨，不是退回经典列表。
- 轨道只实例化选中附近的窗口，避免 `loadMore` 之后 ForEach 越来越重。
- 命令面板 popover 只挂在当前选中卡上。
- 卡片头图用已有类型色，不再在首帧同步采样 App 图标。

## 范围外

- 不重写成 `NSCollectionView`。
- 不改经典列表、不改瀑布流图片网格。
- 不接回 GeometryReader 量高、不在拖拽中回写卡片高度。
- 不把改动推到 upstream。

## 验收标准

- [ ] 底部悬浮打开时窗口一次到位，无 0.22s 上滑。
- [ ] `QuickClipCard` 无逐卡投影、无 hover 缩放、无选中弹簧；选中只改描边/头图色。
- [ ] `quickPanelBottomShell()` 不再叠加 blur 和 SwiftUI 大阴影。
- [ ] `QuickPanelBottomRailWindow.range` 单测覆盖空列表、首项、中间、末项、窗口夹紧。
- [ ] `swift test` / `swift build` 通过。
- [ ] 本机用 `./scripts/rebuild_and_open_stable.sh` 重装后，打开面板和左右切卡不再明显掉帧。
