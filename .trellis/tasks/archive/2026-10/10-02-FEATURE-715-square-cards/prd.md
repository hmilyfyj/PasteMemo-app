# FEATURE-715 悬浮框正方形卡片与底部显示

## Goal

底部悬浮卡片保持正方形，完整显示底部元信息和快捷键；完成本机 ARM 安装及 PR 交付。

## Requirements

- 卡片保持正方形；底部元信息和快捷键完整可见。
- 保留横向懒加载、选择、右键和粘贴行为。

## Acceptance Criteria

- [x] 默认高度、最小高度 212pt、展开预览均完整显示。
- [x] make test（437 项）、make check 通过。
- [x] 构建并启动本机 ARM 应用；交付 origin/main PR。

## Notes

- 修改边界：QuickPanelView 卡片区尺寸分配、QuickClipCard 固定尺寸约束。
- 使用卡片区实际高度，尺寸观察仅在高度改变时更新；不引入 GeometryReader。
- 不更改经典面板、窗口位置、数据模型或用户设置。
- 小于 188pt 时整张卡片等比缩放，避免固定标题及底栏在小尺寸下溢出。
- 原图验收裁剪仅保留单张卡片；验证后恢复全宽、401pt 高度及紧凑模式。
