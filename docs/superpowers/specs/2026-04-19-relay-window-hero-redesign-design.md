# 接力窗口重构设计（Hero 卡片 + 抽屉）

## 背景

当前接力面板（`RelayQueueView`）在 280px 宽的浮窗里挤满了：双行工具栏（反转/清空/循环/齿轮）、规则 banner、队列列表、上一条/跳过、结束后自动退出勾选、暂停/退出/清空退出三按钮。功能完整但视觉局促，用户反馈"像把所有东西塞进一个小窗"。

自动化规则在 v1.5.0 里扩展了接力粘贴路径（issue #22 / Plan B），用户会更依赖接力来"批量粘贴 + 规则转换"的工作流。接力面板作为此工作流的核心 UI，需要重构以适应加深的使用频率。

## 目标

1. **降低视觉密度**：默认态只显示"当前在粘什么、进度到哪儿、怎么往下/往回"。
2. **信息按需展开**：完整队列、管理按钮放抽屉，偶尔查看。
3. **符合粘贴节奏**：主操作（跳过）视觉优先，次操作（上一条）弱化。
4. **删除防悔**：接力中删除条目自动回流剪贴板历史，避免永久丢失。

## 整体形态

**Hero 卡片 + 抽屉**：默认紧凑态只展示当前条内容和核心操作；底栏点 `▼` 展开下方抽屉，显示完整队列 + 管理按钮。两态通过一个高度动画切换，不是 tab 不是新窗口。

窗口宽度 300px（略宽于当前 280），支持用户拖宽；记忆最后宽度。

## 分层决策

按可见频率分三层：

- **L1 永远可见（Hero 卡片）**：计数 · 规则 pill · 齿轮 · 当前内容 · 预览 diff · 进度色块 · 上一条/跳过 · 循环 · 结束后自动退出 · 暂停 · 退出 · 清空退出 · 展开把手
- **L2 抽屉展开**：完整队列列表（含 hover 工具按钮）· 反转 · 清空
- **L3 齿轮 popover（设置）**：纯文本粘贴 · 允许重复复制 · 规则选择 · 启用预览 · 完成音效 · 粘贴后按键

## Hero 卡片（紧凑态）详细布局

自上而下 6 个分区，宽 300px：

### 1. 顶栏（`cursor:grab` 整条可拖动）
- 左：计数 `2/5`（等宽数字）
- 中：规则 pill — 图标 `⚡` + 规则名 + 可选 `· 启用预览` + 右侧 `×`；点击 pill 右键出菜单切换规则，点 × 清除
- 右：齿轮 ⚙ 打开 L3 popover

### 2. 当前内容
- 来源小标签：来源 App 图标 + localizedName（如 `📘 Microsoft Word`）
- 内容主文：13pt 3 行内（超出截断），原始内容
- 预览 diff（仅当 L3 `启用预览` 开启且有规则匹配）：紧贴主文下方一个绿色左边框引用块，显示 `→ <转换后文本>`

### 3. 进度色块
- 5 格等宽（队列长时横向压缩，最小 4px 宽）
- 颜色语义：done 绿淡 / current 蓝实 / pending 灰 / skipped 灰斜线
- hover 单格弹出 tooltip 显示该条内容截断 + 来源图标

### 4. 主操作（按钮组 C 布局）
- 左侧弱按钮 `◀ 上一条`（次要色、小号）
- 右侧强按钮 `跳过 ▶`（蓝色主按钮、略大）
- 中间 flex 空白，窗口变宽时不撑大按钮，只撑空白

### 5. 模式行
- `↻ 循环` toggle（SwiftUI Toggle.switch 的紧凑样式，带激活色）
- `◻ 结束后自动退出` checkbox（紧凑）
- 两项水平排列，无标题头

### 6. 底栏
- 左起三个 pill：`⏸ 暂停`（灰）· `✕ 退出`（灰，保留队列）· `🗑 清空退出`（红，清队列）
- 右侧：`▼ 展开` 把手（点击切换抽屉）

## 抽屉展开态

在第 5 区和第 6 区之间插入抽屉内容，整个卡片向下长出：

### 抽屉头
- 左：`队列 5` 标签
- 右：`↕ 反转` pill + `🗑 清空` pill（红）

### 队列列表
每行高度 32-40px（启用预览时 2 行；否则 1 行）：

- **前缀**：状态点（`✓ done` / `▶ current` / `◯ pending` / skipped 斜线）+ 来源 App 图标
- **内容**：1-2 行截断预览
  - 启用预览时第 2 行显示 `→ <转换后截断>`（小字、次级色）
- **后缀（互斥）**：
  - current 且未 hover → 显示粘贴后按键 glyph（`⏎` / `⇥` / `␣` / `↑↓←→`）
  - 任何行 hover → 显示 `✂ 拆分`（条目有多字符时）+ `🗑 删除`（红色图标）
- **支持拖放重排**（沿用现在的 `RelayDropDelegate`）
- **右键菜单**（保留当前实现）：拆分（多字符）/ 删除

### 行高/间距
- 行间 gap 2px（和当前一致）
- hover 背景淡化 4-8%
- current 行蓝色边框 + 浅底

## 空状态

队列为空时，卡片中部改为居中图标 + 文案：
- 图标：`📋`（大号半透明）
- 主文：`复制内容自动加入队列`
- 次文：`接力模式下快捷粘贴已暂停`
- 其他分区（顶栏、底栏、模式行）保持显示

## 新功能：删除回流剪贴板历史

**动机**：接力激活时 `ClipboardManager` 主监听被暂停（`RelayManager.activate` 内 `clipboardController?.pauseMonitoring()`），接力期间复制的条目只进入接力队列，不入剪贴板历史。一旦用户在接力中删除这类条目，就永久丢失。

**行为**：`RelayManager.deleteItem(at:)` 内新增一步 `recirculateToClipboardHistory(_ item: RelayItem)`：

1. 通过 `ClipboardManager.shared.insertOrUpdate` 写入一条与该 RelayItem 等价的 ClipItem
   - `content` / `imageData` / `contentType`（从 `contentKind` 映射）/ `sourceAppBundleID` / `pasteboardSnapshot` / `richTextData` 全部继承
2. 去重：如果剪贴板历史已存在同 content/同 imageData 的条目，仅更新 `lastUsedAt`，不插入重复
3. 触发 toast：`已从接力删除，保留在剪贴板历史`，带 `撤销` 按钮（6s 可点；过期后 toast 消失但 ClipItem 继续留着）

**撤销语义**：撤销 = 把刚刚从队列删除的 item 按原位置 splice 回来，并把刚写的 ClipItem 标记删除（若为本次新插入）。

## 齿轮 Popover（L3，不变）

沿用现有 `RelaySettingsPopover`，6 项：
1. 纯文本粘贴 toggle
2. 允许重复复制 toggle
3. 自动化规则选择（下拉）
4. 启用预览 toggle（规则为空时禁用）
5. 完成提示音 picker
6. 粘贴后按键 picker

不做改动。

## 窗口行为

| 行为 | 实现 |
| --- | --- |
| 拖动窗口 | 顶栏 `WindowDragArea` 覆盖整个顶栏分区 |
| 调整宽度 | 保留现有 `MIN_WIDTH` / `MAX_WIDTH` + 右下 resize handle |
| 宽度记忆 | 沿用现有 `WIDTH_PREF_KEY` UserDefaults 存储 |
| 抽屉高度动画 | `.animation(.easeOut(duration: 0.2))` on `showDrawer` bool |
| 位置记忆 | 沿用现有 `pinTopRight` / 用户拖动后的位置 |

## 代码层改动范围

**重写**：
- `Sources/Views/Relay/RelayQueueView.swift` — 几乎全量重写，按新分区拆子 View
- `Sources/Views/Relay/RelayFloatingWindowController.swift` — 调整默认宽度 300、保留宽度记忆

**拆分**（建议把新文件从 RelayQueueView 中分出）：
- `RelayHeroCard.swift` — Hero 卡片主体（L1 分区）
- `RelayQueueList.swift` — 抽屉队列列表 + 行 Row
- `RelayRow.swift` — 单行（hover 工具、粘贴后按键 glyph、预览 diff 二级）
- `RelayEmptyState.swift` — 空状态组件

**新增**：
- `Sources/Relay/RelayRecirculation.swift` — 封装删除回流 ClipItem 的逻辑 + toast 撤销
- L10n：新增 key `relay.deletedRecirculated` 等 + 11 语言同步

**不动**：
- `RelaySettingsPopover.swift`
- `RelayManager.swift`（仅 `deleteItem` 内加一行调用回流）
- `RelayPaster.swift` / `RelayRuleResolver.swift` / `RelayClipboardMonitor.swift`

## 非目标

- 不引入双栏布局（方案 B 已被否）
- 不引入菜单栏 popover（方案 ③ 已被否）
- 不重做 L3 popover（保持现状）
- 不改接力的监听/粘贴/规则匹配逻辑（这次发版已在 v1.5.0 修好）
- 不加多选批量删除
- 不加条目搜索 / 过滤（队列短，不需要）

## 测试要点

1. 紧凑态 ↔ 抽屉态切换的高度动画顺滑
2. 预览 diff 只在规则匹配且启用预览时渲染，不匹配时不占空间
3. current 行右侧 glyph 与 hover 工具按钮互斥
4. 删除后 toast 显示 6s，撤销真的能把条目插回原位置（含 done / current / pending 各状态）
5. 窗口拓宽到 460 时，上一条/跳过按钮仍保持在两端，中间空白不撑按钮
6. 空状态下 hero 分区结构不崩（底栏仍可用）
7. 拖放重排在抽屉展开态仍然生效
8. 粘贴后按键 glyph 切换设置后，current 行的 glyph 跟随更新

## Release

定为 **v1.6.0**（大版本 UI 重构）。v1.5.0 先发（issue #22 + Plan B + 自动化增强 + 来源图标已 commit）。
