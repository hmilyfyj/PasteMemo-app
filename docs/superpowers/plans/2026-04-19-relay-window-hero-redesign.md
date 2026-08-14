# 接力窗口重构 Implementation Plan（Hero + 抽屉）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `RelayQueueView` 从"全功能密集小窗"重构为 Hero 卡片（L1 永远可见）+ 可展开抽屉（L2 队列列表）+ 齿轮 popover（L3 不变）的三层形态，并新增"删除接力条目自动回流到剪贴板历史"能力（带撤销）。

**Architecture:** 自下而上：先落地 `RelayRecirculation` 逻辑 + 单测；在 `RelayManager.deleteItem` 里挂钩；然后从叶子组件（`RelayRow` / `RelayEmptyState`）开始拆独立 SwiftUI View，再聚合成 `RelayQueueList` / `RelayHeroCard`；最后把 `RelayQueueView` 重写为壳组装这些组件，加上抽屉切换动画和撤销 toast overlay。

**Tech Stack:** SwiftUI (macOS 14+), SwiftData, Swift Testing (`@Test` / `#expect`). 构建验证用 `./scripts/build-dev.sh`。项目 spec 见 `docs/superpowers/specs/2026-04-19-relay-window-hero-redesign-design.md`。

**文件结构：**
- 新建：
  - `Sources/Relay/RelayRecirculation.swift` — 删除回流 ClipItem + 撤销句柄
  - `Sources/Views/Relay/RelayRow.swift` — 单行 View（hover / glyph / diff 二级）
  - `Sources/Views/Relay/RelayEmptyState.swift` — 空状态 View
  - `Sources/Views/Relay/RelayQueueList.swift` — 抽屉队列列表（含头部反转/清空）
  - `Sources/Views/Relay/RelayHeroCard.swift` — Hero L1 分区
  - `Sources/Views/Relay/RelayUndoToast.swift` — 带"撤销"按钮的 toast overlay
  - `Tests/RelayRecirculationTests.swift`
- 重写：
  - `Sources/Views/Relay/RelayQueueView.swift` — 变成外壳
- 微调：
  - `Sources/Views/Relay/RelayFloatingWindowController.swift` — 默认宽度 280→300
  - `Sources/Relay/RelayManager.swift` — `deleteItem` 内挂钩回流 + 暴露 `insertItem(at:item:)` 给撤销用
  - `Sources/Localization/<11>.lproj/Localizable.strings` — 新增 3 个 key

---

## Phase 1 — 逻辑层 + L10n

### Task 1: 新增 L10n 3 个 key（11 语言）

**Files:**
- Modify: 所有 11 个 `Sources/Localization/*.lproj/Localizable.strings`

- [ ] **Step 1: 准备 11 语言的三个新键**

键列表（anchor：插在现有 `relay.emptyHint` 下方）：

| key | zh-Hans | zh-Hant | en | ja | ko | de | es | fr | it | ru | id |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `relay.deleted.recirculated` | 已从接力删除，保留在剪贴板历史 | 已從接力刪除，保留在剪貼簿歷史 | Removed from relay, kept in clipboard history | リレーから削除（クリップボード履歴に保持） | 릴레이에서 삭제됨 (클립보드 기록에 유지) | Aus Relay entfernt, in Zwischenablage-Verlauf erhalten | Eliminado de relay, guardado en historial del portapapeles | Retiré du relais, conservé dans l'historique | Rimosso dal relay, conservato nella cronologia | Удалено из реле, сохранено в истории | Dihapus dari relay, disimpan di riwayat clipboard |
| `relay.deleted.undo` | 撤销 | 撤銷 | Undo | 元に戻す | 실행 취소 | Rückgängig | Deshacer | Annuler | Annulla | Отменить | Urungkan |
| `relay.queue.heading` | 队列 %d | 佇列 %d | Queue %d | キュー %d | 대기열 %d | Warteschlange %d | Cola %d | File %d | Coda %d | Очередь %d | Antrian %d |

- [ ] **Step 2: 用 Agent 并行更新 11 个文件**

对每个语言文件 `Sources/Localization/<lang>.lproj/Localizable.strings`，在 `"relay.emptyHint" = ...;` 那行之后插入三行：

```
"relay.deleted.recirculated" = "<trans>";
"relay.deleted.undo" = "<trans>";
"relay.queue.heading" = "<trans>";
```

推荐用 11 个并行 Agent 各处理一个文件，保持 diff 一致。

- [ ] **Step 3: 构建验证**

```bash
./scripts/build-dev.sh 2>&1 | tail -10
```

Expected: `Build complete!` — 验证 L10n 文件无语法错误。

- [ ] **Step 4: Commit**

```bash
git add Sources/Localization/*/Localizable.strings
git commit -m "i18n(relay): add 3 keys for recirculation toast + queue heading"
```

---

### Task 2: RelayRecirculation 单测（TDD — 红）

**Files:**
- Create: `Tests/RelayRecirculationTests.swift`

- [ ] **Step 1: 写测试套（目前 API 不存在，测试会编译失败）**

```swift
import Foundation
import SwiftData
import Testing
@testable import PasteMemo

@Suite("RelayRecirculation")
struct RelayRecirculationTests {

    @MainActor private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ClipItem.self, SmartGroup.self, AutomationRule.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("Text item recirculates into clipboard history as new ClipItem")
    @MainActor func recirculateTextInsertsNew() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let item = RelayItem(
            content: "hello world",
            contentKind: .text,
            sourceAppBundleID: "com.apple.Safari"
        )

        let handle = RelayRecirculation.recirculate(item, originalIndex: 0, context: context)
        try context.save()

        let clips = try context.fetch(FetchDescriptor<ClipItem>())
        #expect(clips.count == 1)
        #expect(clips[0].content == "hello world")
        #expect(clips[0].sourceAppBundleID == "com.apple.Safari")
        #expect(handle.insertedClipID != nil)
        #expect(handle.originalIndex == 0)
    }

    @Test("Duplicate text item bumps lastUsedAt without creating a new row")
    @MainActor func recirculateTextDedupes() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let existing = ClipItem(
            content: "hello",
            contentType: .text,
            createdAt: Date(timeIntervalSince1970: 100),
            lastUsedAt: Date(timeIntervalSince1970: 100)
        )
        context.insert(existing)
        try context.save()
        let existingID = existing.persistentModelID

        let item = RelayItem(content: "hello", contentKind: .text)
        let handle = RelayRecirculation.recirculate(item, originalIndex: 2, context: context)
        try context.save()

        let clips = try context.fetch(FetchDescriptor<ClipItem>())
        #expect(clips.count == 1)
        #expect(clips[0].persistentModelID == existingID)
        #expect(clips[0].lastUsedAt > Date(timeIntervalSince1970: 100))
        #expect(handle.insertedClipID == nil, "should not mark as newly inserted when deduped")
    }

    @Test("Image item recirculates with imageData")
    @MainActor func recirculateImage() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let item = RelayItem(
            content: "[Image]",
            imageData: data,
            contentKind: .image
        )

        let handle = RelayRecirculation.recirculate(item, originalIndex: 0, context: context)
        try context.save()

        let clips = try context.fetch(FetchDescriptor<ClipItem>())
        #expect(clips.count == 1)
        #expect(clips[0].contentType == .image)
        #expect(clips[0].imageData == data)
        #expect(handle.insertedClipID != nil)
    }

    @Test("File item recirculates as .file contentType")
    @MainActor func recirculateFile() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let item = RelayItem(
            content: "/Users/foo/bar.txt",
            contentKind: .file
        )

        _ = RelayRecirculation.recirculate(item, originalIndex: 0, context: context)
        try context.save()

        let clips = try context.fetch(FetchDescriptor<ClipItem>())
        #expect(clips.count == 1)
        #expect(clips[0].contentType == .file)
        #expect(clips[0].content == "/Users/foo/bar.txt")
    }

    @Test("Undo removes newly-inserted clip")
    @MainActor func undoRemovesInsertedClip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let item = RelayItem(content: "tmp", contentKind: .text)
        let handle = RelayRecirculation.recirculate(item, originalIndex: 0, context: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<ClipItem>()).count == 1)

        RelayRecirculation.undoClipInsertion(handle, context: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<ClipItem>()).count == 0)
    }

    @Test("Undo on deduped insertion is no-op for clipboard history")
    @MainActor func undoDedupedIsNoop() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let existing = ClipItem(content: "hello", contentType: .text)
        context.insert(existing)
        try context.save()

        let item = RelayItem(content: "hello", contentKind: .text)
        let handle = RelayRecirculation.recirculate(item, originalIndex: 0, context: context)
        try context.save()

        RelayRecirculation.undoClipInsertion(handle, context: context)
        try context.save()

        // Existing item stays.
        let clips = try context.fetch(FetchDescriptor<ClipItem>())
        #expect(clips.count == 1)
        #expect(clips[0].content == "hello")
    }
}
```

- [ ] **Step 2: 运行测试，确认编译失败**

```bash
swift test --filter RelayRecirculationTests 2>&1 | tail -5
```

Expected: 编译错误 — `cannot find 'RelayRecirculation' in scope`。符合 TDD 红灯阶段。

---

### Task 3: 实现 RelayRecirculation（TDD — 绿）

**Files:**
- Create: `Sources/Relay/RelayRecirculation.swift`

- [ ] **Step 1: 写实现**

```swift
import Foundation
import SwiftData

@MainActor
enum RelayRecirculation {

    /// Handle returned from `recirculate` so callers can splice the relay item back
    /// into its queue position and (optionally) remove the freshly-inserted ClipItem.
    struct UndoHandle {
        let relayItem: RelayItem
        let originalIndex: Int
        /// `nil` when recirculation deduplicated into an existing ClipItem —
        /// in that case there is nothing to remove from clipboard history on undo.
        let insertedClipID: PersistentIdentifier?
    }

    /// Write `item` back into clipboard history so the user can recover it from the
    /// main app window / quick panel after deleting from the relay queue. If the
    /// content already exists as a ClipItem, only bump `lastUsedAt` (avoids a
    /// duplicate row on repeated copy-relay-delete cycles).
    static func recirculate(
        _ item: RelayItem,
        originalIndex: Int,
        context: ModelContext
    ) -> UndoHandle {
        let contentType = contentType(for: item)
        let staging = ClipItem(
            content: item.content,
            contentType: contentType,
            sourceAppBundleID: item.sourceAppBundleID,
            imageData: item.imageData,
            pasteboardSnapshot: item.pasteboardSnapshot
        )

        if let existing = ClipboardManager.shared.findExistingDuplicate(for: staging, in: context) {
            ClipboardManager.shared.reuseExistingDuplicate(existing, with: staging, in: context)
            return UndoHandle(
                relayItem: item,
                originalIndex: originalIndex,
                insertedClipID: nil
            )
        }

        context.insert(staging)
        return UndoHandle(
            relayItem: item,
            originalIndex: originalIndex,
            insertedClipID: staging.persistentModelID
        )
    }

    /// Undo `recirculate`: remove the ClipItem that `recirculate` inserted. When
    /// recirculation deduplicated into an existing row (insertedClipID == nil) we
    /// intentionally leave clipboard history alone — the existing row pre-dates the
    /// user's deletion.
    static func undoClipInsertion(_ handle: UndoHandle, context: ModelContext) {
        guard let id = handle.insertedClipID else { return }
        guard let clip = context.model(for: id) as? ClipItem else { return }
        context.delete(clip)
    }

    private static func contentType(for item: RelayItem) -> ClipContentType {
        switch item.contentKind {
        case .image: return .image
        case .file: return .file
        case .text: return .text
        }
    }
}

// `ClipItem` has a convenience initializer for the full payload we use above.
// If one doesn't exist yet, add a convenience init:
// init(content:, contentType:, sourceAppBundleID:, imageData:, pasteboardSnapshot:)
// alongside the existing ClipItem designated initializer.
```

- [ ] **Step 2: 确认 ClipItem 有兼容的初始化器**

```bash
grep -n "init(" Sources/Models/ClipItem.swift | head -5
```

查看 `ClipItem` 的 init 签名。如果现有 init 不支持我们用的参数组合，在 `Sources/Models/ClipItem.swift` 追加一个 convenience init（不改主 init）：

```swift
// At the bottom of the `final class ClipItem` definition:
convenience init(
    content: String,
    contentType: ClipContentType,
    sourceAppBundleID: String?,
    imageData: Data?,
    pasteboardSnapshot: Data?
) {
    self.init(
        content: content,
        contentType: contentType,
        imageData: imageData
    )
    self.sourceAppBundleID = sourceAppBundleID
    self.pasteboardSnapshot = pasteboardSnapshot
}
```

如果主 init 已支持所有参数，跳过这一步。

- [ ] **Step 3: 运行测试，确认通过**

```bash
swift test --filter RelayRecirculationTests 2>&1 | tail -15
```

Expected: 6 个测试全部 PASS。

- [ ] **Step 4: build-dev 编译验证整个项目**

```bash
./scripts/build-dev.sh 2>&1 | tail -5
```

Expected: `Build complete!` 无其他编译错误。

- [ ] **Step 5: Commit**

```bash
git add Sources/Relay/RelayRecirculation.swift Sources/Models/ClipItem.swift Tests/RelayRecirculationTests.swift
git commit -m "feat(relay): RelayRecirculation — delete-to-clipboard-history with undo"
```

---

### Task 4: RelayManager.deleteItem 挂钩回流 + 暴露 insertItem

**Files:**
- Modify: `Sources/Relay/RelayManager.swift`

- [ ] **Step 1: 在 RelayManager 里新增 `@Published var lastRecirculation: RelayRecirculation.UndoHandle?`**

在 `@MainActor final class RelayManager` 声明的 `@Published var currentIndex` 附近加：

```swift
@Published var lastRecirculation: RelayRecirculation.UndoHandle?
private var lastRecirculationExpiry: Task<Void, Never>?
```

- [ ] **Step 2: 改写 `deleteItem(at:)`**

在 `RelayManager.swift` 找到现有 `func deleteItem(at index: Int)`，改为：

```swift
func deleteItem(at index: Int) {
    guard index >= 0, index < items.count else { return }
    let removed = items[index]
    items.remove(at: index)
    if index < currentIndex {
        currentIndex -= 1
    } else if index == currentIndex, currentIndex >= items.count, !items.isEmpty {
        currentIndex = items.count - 1
    }
    markCurrentIfNeeded()
    windowController?.updateSize(for: items.count)

    // Recirculate to clipboard history so the clip is not permanently lost.
    let context = ModelContext(PasteMemoApp.sharedModelContainer)
    let handle = RelayRecirculation.recirculate(removed, originalIndex: index, context: context)
    try? context.save()
    scheduleRecirculationExpiry(handle)
}

private func scheduleRecirculationExpiry(_ handle: RelayRecirculation.UndoHandle) {
    lastRecirculation = handle
    lastRecirculationExpiry?.cancel()
    lastRecirculationExpiry = Task { [weak self] in
        try? await Task.sleep(for: .seconds(6))
        guard !Task.isCancelled, let self else { return }
        if self.lastRecirculation?.relayItem.id == handle.relayItem.id {
            self.lastRecirculation = nil
        }
    }
}

func undoLastRecirculation() {
    guard let handle = lastRecirculation else { return }
    let target = min(handle.originalIndex, items.count)
    items.insert(handle.relayItem, at: target)
    if target <= currentIndex {
        currentIndex += 1
    }
    markCurrentIfNeeded()
    windowController?.updateSize(for: items.count)

    let context = ModelContext(PasteMemoApp.sharedModelContainer)
    RelayRecirculation.undoClipInsertion(handle, context: context)
    try? context.save()

    lastRecirculation = nil
    lastRecirculationExpiry?.cancel()
}
```

- [ ] **Step 3: 扩展 RelayManagerTests.deleteItem 测试保证未破坏行为**

打开 `Tests/PasteMemoTests.swift`，确认现有 `@Test("Delete removes item and adjusts pointer")` 仍然通过（`makeManager` 已经 deactivate / 无 container 注入，我们的回流调用拿 `PasteMemoApp.sharedModelContainer`）。

实际测试环境下 `sharedModelContainer` 指向本地磁盘 store — 在测试运行环境下这可能写入 dev 用户数据。我们需要保护。

**实施：** 在 `deleteItem` 内新增一道守卫：队列不在 active 状态时，跳过回流。

```swift
// 在 deleteItem 里，回流之前：
guard isActive else { return }
// … 回流调用
```

然后把回流部分包在这个 guard 下。`makeManager` 测试起始调 `deactivate()`，所以测试中 `isActive == false`，测试不会触碰 sharedModelContainer。

- [ ] **Step 4: 运行 RelayManager 测试**

```bash
swift test --filter RelayManagerTests 2>&1 | tail -15
```

Expected: 所有 RelayManager 测试继续 PASS（包括 deleteItem）。

- [ ] **Step 5: 全量 build + RelayRecirculation 测试**

```bash
./scripts/build-dev.sh 2>&1 | tail -5
swift test --filter RelayRecirculationTests 2>&1 | tail -5
```

Expected: build complete + 6 recirculation tests PASS。

- [ ] **Step 6: Commit**

```bash
git add Sources/Relay/RelayManager.swift
git commit -m "feat(relay): wire deleteItem to recirculation + 6s undo window"
```

---

## Phase 2 — View 组件（自叶向根拆分）

### Task 5: 创建 RelayRow.swift（单行 View）

**Files:**
- Create: `Sources/Views/Relay/RelayRow.swift`
- Reference: 现有 `Sources/Views/Relay/RelayQueueView.swift` 第 427-570 行 `RelayQueueRow`

- [ ] **Step 1: 复制当前 RelayQueueRow 为基础，调整到新需求**

```swift
import AppKit
import SwiftUI

/// 单条接力队列的 Row：状态点 · 来源 App 图标 · 内容（可选二级 diff 预览）· current 时的
/// 粘贴后按键 glyph / hover 时的 [✂ 拆分] [🗑 删除] 工具按钮。
struct RelayRow: View {
    let item: RelayItem
    let previewRule: AutomationRule?
    var onDelete: (() -> Void)?
    var onSplit: (() -> Void)?

    @State private var isHovering = false
    @AppStorage(RelayPostPasteKey.userDefaultsKey) private var postPasteKeyRaw = RelayPostPasteKey.none.rawValue

    /// 仅在规则条件匹配时返回 actions（和 `RelayRuleResolver.actionsApplying` 对齐）。
    private var effectivePreviewActions: [RuleAction] {
        guard let rule = previewRule, item.contentKind == .text else { return [] }
        let contentType = ClipboardManager.shared.detectContentType(item.content).type
        let ok = rule.conditions.isEmpty || AutomationEngine.matchesConditions(
            rule.conditions,
            logic: rule.conditionLogic,
            content: item.content,
            contentType: contentType,
            sourceApp: item.sourceAppBundleID
        )
        return ok ? rule.actions : []
    }

    private var primaryText: String {
        item.isFile ? item.displayName : item.content.replacingOccurrences(of: "\n", with: " ↵ ")
    }

    private var previewText: String? {
        guard !effectivePreviewActions.isEmpty else { return nil }
        let processed = AutomationEngine.apply(effectivePreviewActions, to: item.content)
        guard processed != item.content else { return nil }
        return processed.replacingOccurrences(of: "\n", with: " ↵ ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            stateIndicator
                .padding(.top, 2)
            sourceAppBadge
                .padding(.top, 1)
            contentColumn
            Spacer(minLength: 0)
            trailingColumn
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(rowBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(item.state == .current ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.1), value: isHovering)
    }

    // MARK: - Subviews

    @ViewBuilder private var stateIndicator: some View {
        switch item.state {
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.green.opacity(0.8))
        case .current:
            Image(systemName: "play.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        case .skipped:
            Image(systemName: "forward.end")
                .font(.system(size: 9))
                .foregroundStyle(.secondary.opacity(0.6))
        case .pending:
            Image(systemName: "circle")
                .font(.system(size: 8))
                .foregroundStyle(.secondary.opacity(0.5))
        }
    }

    @ViewBuilder private var sourceAppBadge: some View {
        if let bundleID = item.sourceAppBundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 12, height: 12)
                .help(bundleID)
        } else {
            Color.clear.frame(width: 12, height: 12)
        }
    }

    @ViewBuilder private var contentColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .font(.system(size: 12))
                .foregroundStyle(textColor)
                .strikethrough(item.state == .skipped, color: .secondary)
            if let preview = previewText {
                Text("→ " + preview)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(.system(size: 10))
                    .foregroundStyle(.green.opacity(0.85))
            }
        }
    }

    @ViewBuilder private var trailingColumn: some View {
        if isHovering {
            HStack(spacing: 6) {
                if !item.isImage, !item.isFile, item.content.count > 1 {
                    Button { onSplit?() } label: {
                        Image(systemName: "scissors").font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                Button { onDelete?() } label: {
                    Image(systemName: "trash").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.8))
            }
        } else if item.state == .current, let glyph = postPasteKeyGlyph {
            Text(glyph)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
        }
    }

    private var textColor: Color {
        switch item.state {
        case .done: return .secondary
        case .current: return .primary
        case .skipped: return .secondary.opacity(0.6)
        case .pending: return .primary.opacity(0.85)
        }
    }

    private var rowBackground: Color {
        if item.state == .current {
            return Color.accentColor.opacity(0.12)
        }
        return isHovering ? Color.primary.opacity(0.04) : Color.clear
    }

    private var postPasteKeyGlyph: String? {
        guard let key = RelayPostPasteKey(rawValue: postPasteKeyRaw), key != .none else { return nil }
        switch key {
        case .none: return nil
        case .return: return "⏎"
        case .tab: return "⇥"
        case .space: return "␣"
        case .up: return "↑"
        case .down: return "↓"
        case .left: return "←"
        case .right: return "→"
        }
    }
}
```

- [ ] **Step 2: build-dev 编译**

```bash
./scripts/build-dev.sh 2>&1 | tail -5
```

Expected: `Build complete!`（新文件不被引用但仍参与编译；类型/API 错误会在此暴露）。

- [ ] **Step 3: Commit**

```bash
git add Sources/Views/Relay/RelayRow.swift
git commit -m "feat(relay): extract RelayRow — single queue entry view"
```

---

### Task 6: RelayEmptyState.swift

**Files:**
- Create: `Sources/Views/Relay/RelayEmptyState.swift`

- [ ] **Step 1: 写空状态**

```swift
import SwiftUI

struct RelayEmptyState: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 24))
                .foregroundStyle(.secondary.opacity(0.6))
            Text(L10n.tr("relay.emptyHint"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(L10n.tr("relay.quickPastePaused"))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}
```

- [ ] **Step 2: build-dev**

```bash
./scripts/build-dev.sh 2>&1 | tail -5
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/Views/Relay/RelayEmptyState.swift
git commit -m "feat(relay): extract RelayEmptyState view"
```

---

### Task 7: RelayQueueList.swift（抽屉队列列表）

**Files:**
- Create: `Sources/Views/Relay/RelayQueueList.swift`

- [ ] **Step 1: 写容器 View**

```swift
import SwiftUI

/// 抽屉里的队列列表：标题（"队列 N"）+ 反转 / 清空 按钮 + 滚动列表（含拖放重排）。
struct RelayQueueList: View {
    @Bindable var manager: RelayManager
    let previewRule: AutomationRule?
    @State private var splitTargetIndex: Int?
    @State private var draggingItem: RelayItem?

    var body: some View {
        VStack(spacing: 0) {
            header
            if manager.items.isEmpty {
                RelayEmptyState()
            } else {
                list
            }
        }
        .onChange(of: splitTargetIndex) {
            guard let index = splitTargetIndex, index < manager.items.count else { return }
            SplitWindowController.shared.show(text: manager.items[index].content) { delimiter in
                _ = manager.splitItem(at: index, by: delimiter)
            }
            splitTargetIndex = nil
        }
    }

    private var header: some View {
        HStack {
            Text(String(format: L10n.tr("relay.queue.heading"), manager.items.count))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
            headerButton(icon: "arrow.up.arrow.down", title: L10n.tr("relay.reverse"), tint: .secondary) {
                manager.reverseItems()
            }
            .disabled(manager.items.isEmpty)
            headerButton(icon: "trash", title: L10n.tr("relay.clearAll"), tint: .red) {
                manager.clearAll()
            }
            .disabled(manager.items.isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    @ViewBuilder private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(manager.items.enumerated()), id: \.element.id) { index, item in
                        RelayRow(
                            item: item,
                            previewRule: previewRule,
                            onDelete: { manager.deleteItem(at: index) },
                            onSplit: { splitTargetIndex = index }
                        )
                        .id(item.id)
                        .contentShape(Rectangle())
                        .onDrag {
                            draggingItem = item
                            return NSItemProvider(object: item.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: RelayDropDelegate(
                            targetIndex: index,
                            manager: manager,
                            draggingItem: $draggingItem
                        ))
                        .contextMenu {
                            if item.content.count > 1 {
                                Button(L10n.tr("relay.split")) { splitTargetIndex = index }
                            }
                            Button(L10n.tr("relay.delete"), role: .destructive) {
                                manager.deleteItem(at: index)
                            }
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 260)
            .onChange(of: manager.currentIndex) {
                if let current = manager.currentItem {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(current.id, anchor: .center)
                    }
                }
            }
            .onChange(of: manager.items.count) {
                if let last = manager.items.last {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func headerButton(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 9))
                Text(title).font(.system(size: 10))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: build-dev**

```bash
./scripts/build-dev.sh 2>&1 | tail -5
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/Views/Relay/RelayQueueList.swift
git commit -m "feat(relay): extract RelayQueueList — drawer list with header"
```

---

### Task 8: RelayHeroCard.swift（L1 Hero 卡片）

**Files:**
- Create: `Sources/Views/Relay/RelayHeroCard.swift`

- [ ] **Step 1: 写 Hero 分区**

```swift
import AppKit
import SwiftData
import SwiftUI

/// 紧凑态永久可见的 Hero 分区：计数 + 规则 pill + 齿轮 / 当前内容 + 预览 diff /
/// 进度色块 / 上一条·跳过 / 循环·结束后自动退出 / 暂停·退出·清空退出 + 抽屉把手。
struct RelayHeroCard: View {
    @Bindable var manager: RelayManager
    @Binding var drawerOpen: Bool
    @State private var showSettingsPopover = false
    @AppStorage("relayAutomationRuleId") private var settingAutomationRuleId = ""
    @AppStorage("relayPreviewEnabled") private var settingPreviewEnabled = false
    @AppStorage("relayLoopEnabled") private var settingLoopEnabled = false
    @Query(filter: #Predicate<AutomationRule> { $0.enabled == true })
    private var enabledRules: [AutomationRule]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().opacity(0.3)
            currentContent
            progressBar
            mainActions
            Divider().opacity(0.3)
            modeRow
            Divider().opacity(0.3)
            bottomBar
        }
    }

    // MARK: - Top bar (count + rule pill + settings)

    private var topBar: some View {
        HStack(spacing: 6) {
            Text(manager.progressText)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
            if let rule = activeRule {
                rulePill(rule)
            } else {
                Color.clear.frame(height: 16)
                Spacer()
            }
            Button { showSettingsPopover.toggle() } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showSettingsPopover, arrowEdge: .top) {
                RelaySettingsPopover()
                    .modelContainer(PasteMemoApp.sharedModelContainer)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(WindowDragArea())
    }

    private var activeRule: AutomationRule? {
        guard !settingAutomationRuleId.isEmpty else { return nil }
        return enabledRules.first { $0.ruleID == settingAutomationRuleId }
    }

    private func rulePill(_ rule: AutomationRule) -> some View {
        Button {
            settingAutomationRuleId = ""
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill").font(.system(size: 9))
                Text(ruleDisplayName(rule)).font(.system(size: 10))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if settingPreviewEnabled {
                    Text("· " + L10n.tr("relay.settings.preview"))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .help(L10n.tr("relay.banner.clickToClear"))
        .contextMenu {
            ForEach(enabledRules) { r in
                Button {
                    settingAutomationRuleId = r.ruleID
                } label: {
                    if r.ruleID == settingAutomationRuleId {
                        Label(ruleDisplayName(r), systemImage: "checkmark")
                    } else {
                        Text(ruleDisplayName(r))
                    }
                }
            }
        }
    }

    // MARK: - Current content

    @ViewBuilder private var currentContent: some View {
        if let item = manager.currentItem {
            VStack(alignment: .leading, spacing: 6) {
                sourceBadge(for: item)
                Text(item.isFile ? item.displayName : item.content)
                    .font(.system(size: 13))
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                if let preview = previewDiff(for: item) {
                    Text("→ " + preview)
                        .font(.system(size: 11))
                        .foregroundStyle(.green.opacity(0.85))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.green.opacity(0.08))
                        )
                        .overlay(
                            Rectangle()
                                .fill(Color.green.opacity(0.4))
                                .frame(width: 2),
                            alignment: .leading
                        )
                        .lineLimit(3)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        } else {
            RelayEmptyState()
        }
    }

    @ViewBuilder private func sourceBadge(for item: RelayItem) -> some View {
        if let bundleID = item.sourceAppBundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            HStack(spacing: 5) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 11, height: 11)
                Text(FileManager.default.displayName(atPath: url.path))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func previewDiff(for item: RelayItem) -> String? {
        guard let rule = activeRule, settingPreviewEnabled, item.contentKind == .text else { return nil }
        let contentType = ClipboardManager.shared.detectContentType(item.content).type
        let ok = rule.conditions.isEmpty || AutomationEngine.matchesConditions(
            rule.conditions,
            logic: rule.conditionLogic,
            content: item.content,
            contentType: contentType,
            sourceApp: item.sourceAppBundleID
        )
        guard ok else { return nil }
        let processed = AutomationEngine.apply(rule.actions, to: item.content)
        return processed == item.content ? nil : processed
    }

    // MARK: - Progress bar (color blocks)

    @ViewBuilder private var progressBar: some View {
        if !manager.items.isEmpty {
            HStack(spacing: 3) {
                ForEach(Array(manager.items.enumerated()), id: \.element.id) { _, item in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: item))
                        .frame(height: 3)
                        .help(item.isFile ? item.displayName : String(item.content.prefix(60)))
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
    }

    private func color(for item: RelayItem) -> Color {
        switch item.state {
        case .done: return .green.opacity(0.5)
        case .current: return Color.accentColor
        case .skipped: return .secondary.opacity(0.3)
        case .pending: return .secondary.opacity(0.15)
        }
    }

    // MARK: - Main actions (prev / skip)

    @ViewBuilder private var mainActions: some View {
        HStack(spacing: 8) {
            Button { manager.rollback() } label: {
                Label(L10n.tr("relay.previous"), systemImage: "chevron.left")
                    .font(.system(size: 10))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(manager.currentIndex == 0)
            .opacity(manager.currentIndex == 0 ? 0.4 : 0.8)

            Spacer()

            Button { manager.skip() } label: {
                HStack(spacing: 3) {
                    Text(L10n.tr("relay.skip"))
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .foregroundStyle(Color.accentColor)
                .background(Color.accentColor.opacity(0.2), in: Capsule())
                .overlay(Capsule().stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(manager.isQueueExhausted)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Mode row

    private var modeRow: some View {
        HStack(spacing: 14) {
            Toggle(isOn: $settingLoopEnabled) {
                Label(L10n.tr("relay.loop"), systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10))
            }
            .toggleStyle(.checkbox)
            .controlSize(.small)

            Toggle(isOn: $manager.autoExitOnEmpty) {
                Text(L10n.tr("relay.autoExit.short"))
                    .font(.system(size: 10))
            }
            .toggleStyle(.checkbox)
            .controlSize(.small)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 6) {
            pillButton(
                icon: manager.isPaused ? "play.fill" : "pause.fill",
                title: manager.isPaused ? L10n.tr("relay.resume") : L10n.tr("relay.pause"),
                tint: manager.isPaused ? .green : .secondary
            ) {
                if manager.isPaused { manager.resume() } else { manager.pause() }
            }

            pillButton(icon: "xmark", title: L10n.tr("relay.exit"), tint: .secondary) {
                manager.deactivate()
            }

            pillButton(icon: "trash", title: L10n.tr("relay.clearAndExit"), tint: .red) {
                manager.deactivate(clearQueue: true)
            }
            .disabled(manager.items.isEmpty)

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.2)) { drawerOpen.toggle() }
            } label: {
                Image(systemName: drawerOpen ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
            .help(drawerOpen ? L10n.tr("relay.collapse") : L10n.tr("relay.expand"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func pillButton(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 8))
                Text(title).font(.system(size: 10))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func ruleDisplayName(_ rule: AutomationRule) -> String {
        let translated = L10n.tr(rule.name)
        return translated == rule.name && rule.name.hasPrefix("automation.") ? rule.name : translated
    }
}
```

- [ ] **Step 2: 确认 L10n `relay.collapse` / `relay.expand` 已存在**

```bash
grep -l "relay.expand\|relay.collapse" Sources/Localization/zh-Hans.lproj/Localizable.strings
```

若缺失，补充：

| key | zh-Hans | zh-Hant | en | ja | ko | de | es | fr | it | ru | id |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `relay.expand` | 展开 | 展開 | Expand | 展開 | 확장 | Einblenden | Expandir | Déplier | Espandi | Развернуть | Buka |
| `relay.collapse` | 收起 | 收合 | Collapse | 折りたたむ | 접기 | Ausblenden | Contraer | Replier | Comprimi | Свернуть | Tutup |

并入 Task 1 的 Commit 或单独补一次 L10n commit。

- [ ] **Step 3: build-dev**

```bash
./scripts/build-dev.sh 2>&1 | tail -5
```

Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add Sources/Views/Relay/RelayHeroCard.swift Sources/Localization/*/Localizable.strings
git commit -m "feat(relay): extract RelayHeroCard — L1 hero with all永久可见控件"
```

---

### Task 9: RelayUndoToast.swift（撤销 toast overlay）

**Files:**
- Create: `Sources/Views/Relay/RelayUndoToast.swift`

- [ ] **Step 1: 写 toast overlay**

```swift
import SwiftUI

/// 接力窗口内嵌的"删除回流"提示 — 显示在 Hero 卡片上方的 overlay，6 秒后自动消失或
/// 用户点撤销后消失。和 GlobalToast 不同：带一个可点的"撤销"按钮。
struct RelayUndoToast: View {
    let message: String
    let actionTitle: String
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green.opacity(0.85))
                .font(.system(size: 12))
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer()
            Button(action: onAction) {
                Text(actionTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
        )
        .padding(8)
    }
}
```

- [ ] **Step 2: build-dev**

```bash
./scripts/build-dev.sh 2>&1 | tail -5
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/Views/Relay/RelayUndoToast.swift
git commit -m "feat(relay): RelayUndoToast — in-window undo toast"
```

---

## Phase 3 — 整合

### Task 10: 重写 RelayQueueView 为壳

**Files:**
- Rewrite: `Sources/Views/Relay/RelayQueueView.swift`

- [ ] **Step 1: 完整重写 RelayQueueView.swift**

```swift
import SwiftData
import SwiftUI

/// 接力浮窗外壳：组装 HeroCard + 可选展开的 QueueList + 撤销 toast overlay。
/// 原来在此文件里的 header / list / footer / row 已拆到独立文件。
struct RelayQueueView: View {
    @Bindable var manager: RelayManager
    @State private var drawerOpen: Bool = false
    @AppStorage("relayAutomationRuleId") private var settingAutomationRuleId = ""
    @AppStorage("relayPreviewEnabled") private var settingPreviewEnabled = false
    @Query(filter: #Predicate<AutomationRule> { $0.enabled == true })
    private var enabledRules: [AutomationRule]

    /// 预览 diff 只在启用预览且规则选中时生效。
    private var previewRule: AutomationRule? {
        guard settingPreviewEnabled, !settingAutomationRuleId.isEmpty else { return nil }
        return enabledRules.first { $0.ruleID == settingAutomationRuleId }
    }

    var body: some View {
        VStack(spacing: 0) {
            RelayHeroCard(manager: manager, drawerOpen: $drawerOpen)
            if drawerOpen {
                Divider().opacity(0.4)
                RelayQueueList(manager: manager, previewRule: previewRule)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
        .overlay(alignment: .top) {
            if let handle = manager.lastRecirculation {
                RelayUndoToast(
                    message: L10n.tr("relay.deleted.recirculated"),
                    actionTitle: L10n.tr("relay.deleted.undo")
                ) {
                    manager.undoLastRecirculation()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(handle.relayItem.id)
            }
        }
        .animation(.easeOut(duration: 0.2), value: manager.lastRecirculation?.relayItem.id)
    }
}
```

- [ ] **Step 2: build-dev**

```bash
./scripts/build-dev.sh 2>&1 | tail -15
```

Expected: `Build complete!`。若有编译错误（比如 `headerButton` 等旧引用），删除旧的 `RelayQueueRow` / `RelayDropDelegate` 定义里未被使用的部分 — 注意 `RelayDropDelegate` 仍被 `RelayQueueList` 依赖，保留。

- [ ] **Step 3: 手测**

1. 启动 Dev 版
2. 按接力快捷键激活接力模式
3. 从 Word 复制 2-3 条文字，确认每条入队列
4. Hero 卡片显示当前条内容 + 来源标签 + 进度条
5. 点 ▼ 展开抽屉 → 队列列表可见 + `队列 3` 标题 + 反转/清空按钮
6. hover 某条 pending → 出现 ✂ / 🗑 按钮
7. 点 🗑 删除 → 底部 overlay 出现撤销 toast → 6 秒后自动消失 或 点撤销恢复条目
8. 打开快捷面板确认被删除的条目出现在剪贴板历史里
9. 粘贴规则（"测试 Word"）依然正常生效
10. 窗口拓宽到 460px → "上一条"靠左弱、"跳过"靠右强，中间空白不撑按钮
11. 队列为空 → 显示"复制内容自动加入队列"空状态
12. ⏸ 暂停 / ✕ 退出 / 🗑 清空退出 三按钮均可点

- [ ] **Step 4: Commit**

```bash
git add Sources/Views/Relay/RelayQueueView.swift
git commit -m "feat(relay): rewrite RelayQueueView as shell over HeroCard + drawer + toast"
```

---

### Task 11: 调整默认窗口宽度

**Files:**
- Modify: `Sources/Views/Relay/RelayFloatingWindowController.swift`

- [ ] **Step 1: 调整常量**

找到 `MIN_WIDTH` / `DEFAULT_WIDTH` / `MAX_WIDTH` 定义，调整默认宽度：

```swift
// 原值可能是 280。改为：
private let DEFAULT_WIDTH: CGFloat = 300
private let MIN_WIDTH: CGFloat = 280
private let MAX_WIDTH: CGFloat = 520
```

（如只有 `WIDTH` 常量，维持当前命名，只改数值。）

- [ ] **Step 2: build-dev + 手测宽度**

```bash
./scripts/build-dev.sh 2>&1 | tail -5
```

启动 Dev 版，首次打开接力窗口，宽度应为 300。拖宽到 520（最大），再收窄到 280（最小）。关闭重开宽度记忆应生效。

- [ ] **Step 3: Commit**

```bash
git add Sources/Views/Relay/RelayFloatingWindowController.swift
git commit -m "feat(relay): raise default width 280→300, cap at 520"
```

---

### Task 12: 最终验证 + v1.6.0 发版准备

- [ ] **Step 1: 全量测试**

```bash
swift test 2>&1 | tail -10
```

Expected: all PASS（无新回归）。

- [ ] **Step 2: 全量 build-dev + 手测**

```bash
./scripts/build-dev.sh 2>&1 | tail -5
```

启动 Dev 版，完整走一遍：

- 激活 → 紧凑态默认 → 从 Word 复制若干条 → 抽屉展开 → 列表项 hover 工具 → 删除一条 → toast → 撤销 → 条目回来
- 规则选择（齿轮 popover）→ 开启预览 → Hero diff 显示 → 抽屉 row diff 显示
- 循环 toggle → 队列耗尽循环回 0 → 结束后自动退出 toggle
- 暂停 / 继续（绿色切换）→ 退出（队列保留下次恢复）→ 清空退出（队列清空）
- 窗口拖动（顶栏） / 宽度调整（边缘） / 关闭重开宽度记忆

- [ ] **Step 3: 截图 + 变更日志**

保存紧凑态 / 展开态 / 空状态 / 撤销 toast 各一张到 `.superpowers/brainstorm/*/content/`，供 release notes 使用。

- [ ] **Step 4: 起草 v1.6.0 release notes**

写入 `.release/v1.6.0-notes.md`：

```markdown
## 更新内容

- **优化** 接力面板重构为 Hero 卡片 + 可展开抽屉形态，视觉更紧凑，信息更聚焦
- **优化** "跳过"作为主操作视觉强调，"上一条"弱化为次操作；窗口宽度可自定义记忆
- **新增** 接力中删除条目自动回流到剪贴板历史，6 秒内可撤销
- **新增** 接力队列每行显示来源 App 图标，条件匹配一目了然

## What's New

- **Improve** Rewrote relay panel as a Hero card + expandable drawer — denser, cleaner, focused on the current clip
- **Improve** "Skip" is now the emphasized primary action; "Previous" becomes a subtle secondary. Window width is user-adjustable and remembered
- **New** Deleting an item from the relay queue automatically recirculates it to clipboard history; 6-second undo toast
- **New** Each relay row shows the source app icon, making rule-condition matching visible at a glance
```

- [ ] **Step 5: Commit 完整 plan 完结**

如果前面步骤已各自 commit，此处无需额外提交。查看 `git log --oneline develop ^86d5b49` 确认 commit 队形整齐。

---

## Self-Review

1. **Spec coverage**：
   - L1/L2/L3 分层 ✓（HeroCard = L1, QueueList = L2, Popover = L3 未动）
   - 6 分区（顶栏/内容/进度/主操作/模式/底栏）✓
   - hover 工具 + glyph ✓（RelayRow 内）
   - 预览 diff（当前条 Hero + 列表行）✓
   - 空状态 ✓（RelayEmptyState）
   - 删除回流 + 撤销 ✓（RelayRecirculation + undo toast + 6s expiry）
   - 拖动/宽度记忆 ✓（WindowDragArea + Task 11）
   - 非目标：双栏/菜单栏/多选/搜索 — 均未出现在 plan ✓

2. **Placeholder scan**：无 TBD/TODO，每段都含完整代码块或可执行命令 ✓

3. **Type consistency**：
   - `RelayRecirculation.UndoHandle` 全篇字段对齐（`relayItem`, `originalIndex`, `insertedClipID`）✓
   - `manager.lastRecirculation` / `manager.undoLastRecirculation()` 定义 vs 调用对齐 ✓
   - `previewRule: AutomationRule?` 参数名跨 View 一致 ✓
   - `drawerOpen: Bool` 在 HeroCard / RelayQueueView 两端一致 ✓

如有遗漏在执行阶段按需补。
