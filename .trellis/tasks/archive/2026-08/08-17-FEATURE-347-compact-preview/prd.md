# FEATURE-347 空格预览并精简顶栏

## 目标

底部悬浮面板打开后，搜索框为空时按空格能预览当前卡片；同时压矮搜索框及其上方空白，把高度让给卡片。

## 背景 / 已知事实

- 用户截图（comment `dde4a7b4`）粉箭头标在搜索框上方空隙。
- `searchBar` 现有 `.padding(.top, 22)` + `.padding(.bottom, 14)` + 18pt 放大镜，光这一行就约 64pt。
- `tabBar` 还有 `.padding(.bottom, 8)`。`bottomFloatingLayout` 的 VStack spacing 是 8，外壳 `contentInset` 是 12。
- 打开后面板会 `isSearchFocused = true`。空格（keyCode 49）只在图片瀑布流网格里处理，底部卡片模式会把空格交给搜索框。
- 预览入口是 `QuickLookHelper.shared.toggle(item:)`，经典面板用 ⌘O（`handleOpenLink`）。

## 需求要点

- 底部悬浮 + 搜索框为空（无 IME 组字）时，空格预览当前选中卡片。
- 搜索框已有文字时，空格仍输入空格。
- 底部样式下压缩搜索行和分类条的上下内边距、图标和字号；经典面板不动。

## 范围外

- 不改经典面板的默认焦点和空格行为。
- 不推代码给上游。

## 验收标准

- [x] 打开底部悬浮、搜索为空，按空格弹出当前卡片 Quick Look。
- [x] 搜索框有字时按空格会打出空格，不误开预览。
- [x] 搜索框上方空隙明显小于截图中的 22pt 顶垫。
- [x] `swift build` 通过并重装本机应用。
