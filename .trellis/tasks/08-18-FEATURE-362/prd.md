# FEATURE-362 底部卡片借鉴 Paste 浅色样式

## Goal

底部悬浮快捷面板在浅色外观下接近商业版 Paste：奶油色毛玻璃外壳、白卡片、饱和彩色头图、同色描边、双行页脚；深色外观保留深色底板但共用同一套彩色头图/描边。切卡和打开不因新样式重新掉帧。

## Background / 已知事实

- Multica FEATURE-362 附件是商业版 Paste 底部胶囊截图：浅色毛玻璃外壳、横向卡片、头图按来源 App/类型上色、右上角 App 图标、白卡身、标题+URL/尺寸双行页脚、头图同色描边。
- 当前实现已经是底部卡片轨：`QuickPanelView.bottomFloatingLayout` + `QuickClipCard`。头图走 `CardColorCache.sampleCenterColor`，把 App 图标画成 36×36 再取中心色，再压到亮度 0.25–0.65，所以头图发闷。
- 外壳 `QuickPanelBottomTheme.shellBackground` 是接近不透明的深色渐变（opacity 0.98），盖住了窗口里已有的 `NSVisualEffectView(material: .headerView)`，毛玻璃看不出来。
- 选中态把整张卡洗成蓝色（`cardBackground` / `headerBackground` 两套蓝），和 Paste 的「头图色描边 + 头图保持类型色」不一致。
- 页脚只有一行 meta（`175 字符` / host / `1400 × 1200`），没有 Paste 那种标题 + 副标题。
- 分类标签 `badge()` 是纯文字胶囊，选中用 `Color.accentColor` 实心蓝，没有类型色圆点。
- FEATURE-361（未合入 main）已验证：逐卡投影、hover `scaleEffect`、选中弹簧、首帧同步取色会掉帧。本轮视觉改动必须沿这条约束走，不重做窗口切片。
- 应用已有 `appearanceMode`（system/light/dark）。窗口材质会跟外观走；SwiftUI 外壳和卡片目前写死深色。

## Requirements

1. **外壳跟外观走**：浅色下外壳/分区半透明浅奶油色，让 `NSVisualEffectView` 透出来；深色下改为半透明深色，不再用 0.98 不透明黑。
2. **卡片白身 + 彩色头**：浅色卡身近白、正文深色；深色卡身深灰、正文浅色。头图用饱和色，来源 App 有品牌色表则用品牌色，否则用类型色。不再在 body 里同步采样图标位图。
3. **同色描边**：未选中 1pt 头图色淡描边，选中 2pt 实色描边。选中不再整卡洗蓝。
4. **双行页脚**：第一行标题（链接标题 / 文件名 / 文本首行），第二行 meta（host / 字符数 / 宽×高）。快捷键徽章保留。
5. **分类圆点**：类型筛选标签左侧加类型色圆点；选中改为浅灰/深色填充胶囊，不用实心蓝。
6. **流畅约束**：不恢复逐卡投影、hover 缩放、选中弹簧、图标取色；不引入 GeometryReader；不在 live resize 里回写高度。
7. **范围**：只改底部悬浮样式。经典列表、瀑布流网格、主窗口详情保持原样。

## Out of Scope

- 不重做分组/收藏体系去模仿 Paste 的 Useful Links / Email Templates。
- 不重写成 `NSCollectionView`，不做 FEATURE-361 的轨道窗口切片。
- 不改经典列表、不改设置页信息架构。
- 不把改动推到 upstream。

## Acceptance Criteria

- [ ] 浅色外观下，底部悬浮外壳是半透明浅色，能看到窗口材质，不再是实心深色条。
- [ ] 卡片头图对 Safari / Maps / Photos / Books 等已知 bundle id 使用品牌色；未知来源回退到类型色。`PasteCardAccent` 单测覆盖这两条。
- [ ] 浅色卡片正文和页脚是深色字；图片卡仍铺满预览区。
- [ ] 选中卡用头图色加粗描边，头图颜色保持类型/品牌色。
- [ ] 类型标签带色点；选中标签不是实心蓝。
- [ ] `QuickClipCard` 没有 hover `scaleEffect`、没有逐卡 `shadow`、没有 `CardColorCache.sampleCenterColor` 调用。
- [ ] `swift test` 通过；本机 `./scripts/rebuild_and_open_stable.sh` 能装上并打开底部悬浮框核对观感。
