# FEATURE-361 执行清单

1. 在 `QuickPanelConfiguration.swift` 增加 `QuickPanelBottomRailWindow`，并补 `Tests/QuickPanelBottomRailWindowTests.swift`。
2. 改 `QuickPanelBottomTheme.quickPanelBottomShell()`：去掉 blur 和 SwiftUI 投影。
3. 改 `QuickClipCard`：去投影 / hover 缩放 / 弹簧；头图改类型色；预览插值降级；选中无动画。
4. 改 `bottomClipRail`：按窗口切片 ForEach；popover 只挂选中卡；边缘 `onAppear` 扩窗或 `loadMore`；`scrollTo` 去掉动画。
5. `show()` 里底部样式强制 `positionBottomFloating(..., animated: false)`。
6. `swift test`、`swift build`。
7. `./scripts/rebuild_and_open_stable.sh` 装到本机。
8. 在 `.trellis/spec/app/` 记一条：底部轨道禁止逐卡投影和打开滑入。

## 验证

```bash
swift test --filter QuickPanelBottomRailWindowTests
swift build
./scripts/rebuild_and_open_stable.sh
```

## 检查点 / 回滚

- 切片单测不过：先修纯函数，不动 UI。
- 构建失败或切卡错位：撤回 `bottomClipRail` 窗口化，保留减特效。
- 本机仍卡：再查 `HighlightedText` / 图片解码，本轮不扩到网格和经典列表。
