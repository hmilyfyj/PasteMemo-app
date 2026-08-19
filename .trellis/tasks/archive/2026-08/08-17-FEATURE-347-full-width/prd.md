# FEATURE-347 悬浮框默认宽度贴边

## 目标

底部悬浮快捷面板首次出现（以及未手动改过宽度）时，宽度跟随当前屏幕可见区域，左右顶到边缘并各留约 12pt 空白。

## 背景 / 已知事实

- 用户截图（comment `098af570`）显示底部悬浮条明显窄于屏幕，右侧空出一大块桌面/浏览器。
- 几何计算在 `Sources/Views/QuickPanel/QuickPanelConfiguration.swift`：`horizontalInset` 现为 `0`，`panelWidth` 名义上等于 `screenFrame.width`，`frame()` 用 `screenFrame.midX` 居中。
- `QuickPanelWindowController.positionBottomFloating` 把 `QuickPanelBottomDefaults.storedWidth()` 当作 preferredWidth。本机 `defaults` 已有 `quickPanelBottomSize.width = 1922` 且 `quickPanelBottomWidthIsCustom = 1`，因此一直用窄宽度，不会走默认算法。
- `storedWidth()` 只要存值 `> 0` 就返回，不看 `widthIsCustomKey`。首次展示时窗口还没按屏幕算完就被 `didResize` 写成自定义宽度。

## 需求要点

- 默认宽度 = 当前屏 `visibleFrame.width - 2 * 水平留白`，水平留白约 12pt。
- 原点贴 `visibleFrame.minX + 留白`，不再靠居中“碰巧”贴边。
- 仅当用户确实拖过宽度（`widthIsCustom`）时才沿用已存宽度；否则每次按当前屏重算。
- 升到本版时清掉旧的 1922 自定义宽度，让现有安装立刻吃到新默认。
- 高度、紧凑/展开、`⌘O`、卡片轨道逻辑不动。

## 范围外

- 不改经典面板尺寸和位置策略。
- 不推代码给上游 `lifedever/PasteMemo-app`。

## 验收标准

- [x] 无已存自定义宽度时，面板左右距屏幕可见边缘约 12pt。
- [x] 换到更宽/更窄的屏后，非自定义宽度会按新 `visibleFrame` 重算。
- [x] 用户拖过宽度后，下次打开仍用拖过的宽度。
- [x] 本机旧 `quickPanelBottomSize.width=1922` 在升级后不再挡住新默认。
- [x] `swift build` 通过，release 装到 `/Applications/PasteMemo.app`。
