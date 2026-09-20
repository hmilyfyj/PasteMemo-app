# FEATURE-362 Implement

## Checklist

1. 新增 `PasteCardAccent`：类型色、品牌色表、`resolved(type:bundleID:)`，亮度抬升给浅色头图用。
2. 改 `QuickPanelBottomTheme`：浅/深 palette、半透明外壳、圆角 26、删 blur/大阴影。
3. 改 `QuickClipCard`：跟 palette、头图用 accent、同色描边、双行页脚、正文深/浅色、去掉对 `CardColorCache` 的调用。
4. 改 `QuickPanelView.badge`：类型标签加色点，选中改成中性填充。
5. 改 `QuickPanelWindowController` 圆角为 26。
6. 补 `Tests/PasteCardAccentTests.swift`。
7. `swift test`；通过后 `./scripts/rebuild_and_open_stable.sh` 本机安装核对。

## Validation

```bash
swift test --filter PasteCardAccentTests
swift test
swift build
./scripts/rebuild_and_open_stable.sh
```

本机核对：切到浅色外观，打开底部悬浮，确认外壳透、卡片白、头图饱和、描边跟头图色、页脚两行、类型标签有色点；左右切卡无明显新掉帧。

## Rollback

还原 `Sources/Views/QuickPanel/{PasteCardAccent.swift,QuickPanelBottomTheme.swift,QuickClipCard.swift,QuickPanelView.swift}`、`QuickPanelWindowController.swift`、`Tests/PasteCardAccentTests.swift`。
