# FEATURE-362 Design

## Boundaries

- 新纯函数放 `Sources/Views/QuickPanel/PasteCardAccent.swift`，给卡片和标签共用，也给单测用。
- 外壳/分区色板继续集中在 `QuickPanelBottomTheme.swift`，按 `ColorScheme` 出浅/深两套。
- 卡片结构仍在 `QuickClipCard.swift`：头图 + 预览 + 页脚。不拆新 View 文件除非页脚逻辑超过一屏。
- 窗口圆角跟主题对齐，只改 `QuickPanelWindowController` 里 `container.layer?.cornerRadius`。
- 不改 `CardColorCache` 的采样实现；卡片不再调用它。缓存类本轮保留，避免无关 diff。

## Color contract

```text
accent = brandColor(bundleID) ?? typeColor(contentType)
headerFill = accent
borderIdle = accent.opacity(0.55)
borderSelected = accent
cardFill(light) = white ~0.96
cardFill(dark) = #1C1C1E
previewText(light) = near-black
previewText(dark) = white 0.92
```

品牌色表只覆盖常见 macOS bundle id（Safari、Maps、Photos、Preview、Books、Notes、Mail、Finder、Chrome、Edge、VS Code、Xcode、WeChat、Telegram）。查表失败回退类型色。类型色沿用 `QuickPanelBottomTheme.headerColor(for:)`，浅色头图再把亮度抬到 0.72–0.90。

## Shell

- `windowCornerRadius` 提到 26，窗口 container 同步。
- 外壳填充改为低不透明度：浅色奶油白 0.42–0.55，深色 0.28–0.40，让 `NSVisualEffectView` 透出来。
- 去掉外壳第二层 blur 描边的依赖（当前 main 还有一层 `blur(0.4)` + 大阴影）。本轮删掉这两层，避免和视觉改动叠卡顿。
- 分区背景同样降不透明度，避免卡片轨再盖一层实色。

## Card

- 头图保持 56pt，右上角 App 图标保留。
- 选中只改描边宽度和头图色描边，不再换蓝渐变底板。
- 页脚两行：`footerTitle` + `metaText`。图片卡页脚叠在预览底部，用很浅的渐变托底，不用大投影。
- 正文颜色走 palette，不再写死 `.white`。
- 不加重 hover、不加重 shadow、不加弹簧。

## Tabs

- `badge(_:isActive:dot:action:)` 增加可选 `dot: Color?`。
- 类型标签传 `PasteCardAccent.typeColor`。
- 选中：浅色用黑 8% 填充 + 深字；深色用白 12% 填充 + 浅字。

## Compatibility / rollback

- 只影响 `quickPanelStyle == bottomFloating`。
- 经典列表、主窗口、设置页不改。
- 回滚：还原上述 4 个 Swift 文件 + 测试文件即可。无数据迁移。

## Trade-offs

- 品牌色表不如实时取色覆盖全，但零位图开销，颜色也更稳、更接近 Paste 的「Safari 蓝 / Maps 绿 / Photos 粉」。
- 浅色外壳依赖窗口已有材质；不换成 `NSGlassEffectView`（仓库注释已排除：文字会发灰）。
- 不做轨道窗口切片，避免和 FEATURE-361 抢同一块重构。
