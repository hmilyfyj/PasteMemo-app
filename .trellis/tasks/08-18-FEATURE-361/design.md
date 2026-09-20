# FEATURE-361 设计

## 边界

只动底部悬浮路径：`QuickPanelBottomTheme`、`QuickClipCard`、`bottomClipRail`、`positionBottomFloating` 打开动画、纯函数窗口切片。经典列表和图片网格不动。

## 数据流

```text
displayOrderItems
  → selectedIndex
  → QuickPanelBottomRailWindow.range(itemCount, selectedIndex, leading, trailing)
  → windowedItems
  → LazyHStack / QuickClipCard
```

- `leadingCount` / `trailingCount` 默认各 20。
- 窗口边缘 `onAppear`：还有未渲染项则把对应侧 +16；已经是数据末尾则 `store.loadMore()`。
- 搜索 / `scrollResetToken` / 面板关闭时把两侧计数重置为 20。
- 选中项落到窗口外（键盘大步跳）时，按选中项重新夹紧窗口。

## 方案取舍

| 方案 | 结论 |
|---|---|
| 整轨改 NSCollectionView | 最接近 Paste，但改动面大、回归风险高。本轮不做。 |
| 只减特效、仍全量 ForEach | 50 条时够用，`loadMore` 后会回来。必须窗口化。 |
| 窗口化 + 减特效 + 去掉打开滑入 | 采用。视觉仍是卡片轨，合成成本接近经典列表。 |
| 头图继续同步取色 | 否。`CardColorCache.sampleCenterColor` 在 MainActor body 里画 bitmap，首屏和滑入新卡都会卡。改用 `QuickPanelBottomTheme.headerColor(for:)`。 |

## 关键合约

`QuickPanelBottomRailWindow.range(itemCount:selectedIndex:leadingCount:trailingCount:) -> Range<Int>`

- 空列表 → `0..<0`
- `selectedIndex` 夹到 `[0, itemCount-1]`
- `start = max(0, selected - leading)`
- `end = min(itemCount, selected + trailing + 1)`
- 选中项必须落在返回区间内（空列表除外）

卡片视觉：

- 选中 = 蓝色描边 + 类型色头图，无投影、无位移、无缩放。
- hover 只用于指针样式，不再 `scaleEffect`。
- 选中切换用 `transaction { $0.animation = nil }`，避免弹簧带动邻卡。
- 预览图插值从 `.high` 降到默认。

窗口：

- `show()` 对底部样式调用 `positionBottomFloating(..., animated: false)`。
- `applyBottomMode` 仍可动画（用户主动 ⌘O，低频）。
- 外壳只保留实色圆角和 1pt 描边；系统窗口阴影继续用 `NSPanel.hasShadow`。

## 兼容与回滚

- 不改 UserDefaults 键，不改卡片数据模型。
- 高度仍只在 `didEndLiveResize` 回写。
- 回滚：还原上述 4 个 Swift 文件 + 测试即可。
