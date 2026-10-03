# 设计

- QuickPanelView：测量轻量 header/footer 固有高度，使用共享纯几何计算给轨道/预览分配空间，不给大历史量轨道套 GeometryReader，不在 AppKit resize 布局回调写 height。
- QuickPanelConfiguration：内容尺寸计算独立于 SwiftUI，最小卡片120pt，轨道内边距4pt，展开预览最小160pt；展开轨道限制为合理高度，其余给预览。
- QuickPanelWindowController：在模式切换及用户结束缩放后同步稳定窗口高度；基于已测 chrome 调整最小高度，防止底栏和预览溢出。测量触发的窗口调整延到下一轮主线程。
- SettingsView：样式切换不清理尺寸，恢复默认只清当前样式；悬浮显示鼠标所在屏幕底部的定位说明，经典保留既有菜单；图片网格设置仅经典展示。
- 新文案走现有本地化，11 种语言保持 key 一致，遵循 LocalizationFilesTests。

风险：大数据量轨道布局、窗口动画、最小尺寸、实时缩放。采用受限几何状态更新及原有 lazy/warm-up 保护，进行本机窗口验证。
