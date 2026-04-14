import SwiftUI
import SwiftData
import AppKit

extension QuickPanelView {
    // MARK: - Actions

    func isEditableType(_ item: ClipItem) -> Bool {
        item.contentType == .text || item.contentType == .code || item.contentType == .link
    }

    func saveEdit() {
        guard let item = editingItem else { return }
        item.content = editingContent
        item.displayTitle = ClipItem.buildTitle(
            content: item.content,
            contentType: item.contentType,
            imageData: item.imageData
        )
        item.isSensitive = SensitiveDetector.isSensitive(
            content: item.content,
            sourceAppBundleID: nil,
            contentType: item.contentType
        )
        ClipItemStore.saveAndNotify(modelContext)
        editingItem = nil
        editingContent = ""
    }

    func cancelEdit() {
        editingItem = nil
        editingContent = ""
    }

    func handleCommandAction(_ action: CommandAction) {
        showCommandPalette = false
        restoreSearchFocusIfNeeded()
        switch action {
        case .paste:
            handlePaste()
        case .cmdEnter:
            if isMultiSelected {
                handleMultiPaste(asPlainText: true, forceNewLine: false)
            } else {
                handleCmdEnter()
            }
        case .copy:
            let items = isMultiSelected ? currentItems : (currentItem.map { [$0] } ?? [])
            if !items.isEmpty { copyItemsToClipboard(items) }
        case .retryOCR:
            if let item = currentItem, item.contentType == .image, item.imageData != nil {
                OCRTaskCoordinator.shared.retry(itemID: item.itemID)
            }
        case .openInPreview:
            if let item = currentItem {
                QuickLookHelper.shared.openInPreviewApp(item: item)
            }
        case .addToRelay:
            let items = isMultiSelected ? currentItems : (currentItem.map { [$0] } ?? [])
            let texts = items.compactMap { $0.content.isEmpty ? nil : $0.content }
            RelayManager.shared.enqueue(texts: texts)
            if !RelayManager.shared.isActive { RelayManager.shared.activate() }
        case .splitAndRelay:
            if let item = currentItem, !item.content.isEmpty {
                relaySplitText = item.content
            }
        case .pin:
            if isMultiSelected {
                let items = currentItems
                let shouldPin = !items.contains(where: \.isPinned)
                for i in items { i.isPinned = shouldPin }
            } else {
                currentItem?.isPinned.toggle()
            }
            ClipItemStore.saveAndNotify(modelContext)
        case .toggleSensitive:
            if isMultiSelected {
                let items = currentItems
                let hasSensitive = items.contains(where: \.isSensitive)
                for i in items { i.isSensitive = !hasSensitive }
            } else {
                currentItem?.isSensitive.toggle()
            }
            ClipItemStore.saveAndNotify(modelContext)
        case .copyColorFormat(let format, _):
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(format, forType: .string)
            showCopiedToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showCopiedToast = false }
        case .showInFinder:
            if let item = currentItem {
                let paths = item.content.components(separatedBy: "\n").filter { !$0.isEmpty }
                if let first = paths.first {
                    NSWorkspace.shared.selectFile(first, inFileViewerRootedAtPath: "")
                }
            }
        case .transform(let ruleAction):
            if let item = currentItem {
                let processed = AutomationEngine.shared.applyAction(ruleAction, to: item.content)
                item.content = processed
                item.displayTitle = ClipItem.buildTitle(content: processed, contentType: item.contentType)
                if ruleAction == .stripRichText {
                    item.richTextData = nil
                    item.richTextType = nil
                }
                ClipItemStore.saveAndNotify(modelContext)
            }
        case .delete:
            handleDeleteSelected()
        }
    }

    func isFileBasedItem(_ item: ClipItem) -> Bool {
        item.contentType.isFileBased && !(item.contentType == .image && item.content == "[Image]")
    }

    func isPureImage(_ item: ClipItem) -> Bool {
        item.contentType == .image && item.content == "[Image]" && item.imageData != nil
    }

    var canPasteToFinderFolder: Bool {
        guard let item = currentItem, item.imageData != nil else { return false }
        return clipboardManager.isFinderApp(QuickPanelWindowController.shared.previousApp)
    }

    func handleMultiPaste(asPlainText: Bool, forceNewLine: Bool = false) {
        let items = currentItems
        guard !items.isEmpty else { return }
        markItemsAsRecentlyUsed(items)

        // Target is Finder → special file handling
        if isTargetFinder, !asPlainText {
            handleMultiPasteToFinder(items)
            return
        }

        let previousApp = QuickPanelWindowController.shared.previousApp
        dismissAndRestoreApp { _ in
            if asPlainText {
                clipboardManager.pasteMultipleAsPlainText(items)
            } else {
                clipboardManager.pasteMultiple(items, forceNewLine: forceNewLine, targetApp: previousApp)
            }
        }
    }

    func handleMultiPasteToFinder(_ items: [ClipItem]) {
        let fileItems = items.filter { isFileBasedItem($0) }
        let textItems = items.filter { !isFileBasedItem($0) && $0.content != "[Image]" }
        let imageItems = items.filter { isPureImage($0) }

        guard let folder = clipboardManager.getFinderSelectedFolder() else {
            // Fallback: paste as files if possible
            dismissAndRestoreApp { _ in clipboardManager.pasteMultiple(items) }
            return
        }

        // Save pure images to folder
        for img in imageItems {
            guard let data = img.imageData else { continue }
            _ = clipboardManager.saveImageToFolder(data, folder: folder)
        }

        // Merge text items into one file
        if !textItems.isEmpty, fileItems.isEmpty {
            let merged = textItems.map(\.content).joined(separator: "\n")
            _ = clipboardManager.saveTextToFolder(merged, folder: folder)
        }

        // File items: paste via file URLs
        if !fileItems.isEmpty {
            let allPaths = fileItems.flatMap { $0.content.components(separatedBy: "\n").filter { !$0.isEmpty } }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            clipboardManager.writeFileURLsToPasteboard(pasteboard, paths: allPaths)
            clipboardManager.lastChangeCount = pasteboard.changeCount
        }

        dismissAndRestoreApp { _ in
            if !fileItems.isEmpty {
                clipboardManager.simulatePaste()
            } else {
                // Images/texts saved to folder, just reveal in Finder
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path)
            }
        }
    }

    func dismissAndRestoreApp(action: @escaping (NSRunningApplication) -> Void) {
        let appToRestore = QuickPanelWindowController.shared.previousApp
        QuickPanelWindowController.shared.dismiss()

        guard let app = appToRestore else { return }
        app.activate()
        Task { @MainActor in
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(50))
                if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier { break }
            }
            try? await Task.sleep(for: .milliseconds(50))
            action(app)
        }
    }

    func markItemsAsRecentlyUsed(_ items: [ClipItem], moveToFront: Bool = false) {
        guard !items.isEmpty else { return }

        let itemIDs = Set(items.map(\.persistentModelID))
        let orderedItems = displayOrderItems.filter { itemIDs.contains($0.persistentModelID) }
        let effectiveItems = orderedItems.isEmpty ? items : orderedItems

        if moveToFront {
            store.moveItemsToFront(effectiveItems)
            rebuildGroupedItems()
        }

        if let focusID = effectiveItems.first?.persistentModelID {
            requestScrollToItem(focusID)
        }

        clipboardManager.markItemsAsUsed(effectiveItems)
    }

    func copyItemsToClipboard(_ items: [ClipItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let merged = items.map(\.content).joined(separator: "\n")
        pasteboard.setString(merged, forType: .string)
        clipboardManager.lastChangeCount = pasteboard.changeCount
        markItemsAsRecentlyUsed(items, moveToFront: true)
        showCopiedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showCopiedToast = false }
    }

    func handleDeleteSelected() {
        let itemsToDelete = isMultiSelected ? currentItems : (currentItem.map { [$0] } ?? [])
        deleteItems(itemsToDelete)
    }

    func copyDebugInfo(for item: ClipItem) {
        let hexContent = item.content.utf8.map { String(format: "%02x", $0) }.joined()
        let hexTitle = (item.displayTitle ?? "").utf8.map { String(format: "%02x", $0) }.joined()
        let info = """
            [PasteMemo Debug Info]
            itemID: \(item.itemID)
            contentType: \(item.contentType.rawValue)
            content.count: \(item.content.count)
            content.hex: \(hexContent)
            content.text: \(item.content)
            displayTitle.hex: \(hexTitle)
            displayTitle.text: \(item.displayTitle ?? "nil")
            hasRichText: \(item.richTextData != nil)
            richTextType: \(item.richTextType ?? "nil")
            """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)
    }

    func deleteItem(_ item: ClipItem) {
        deleteItems([item])
    }

    func assignToGroup(items: [ClipItem], name: String) {
        for item in items {
            let oldGroup = item.groupName
            item.groupName = name
            ClipboardManager.shared.upsertSmartGroup(name: name, context: modelContext)
            if let oldGroup, !oldGroup.isEmpty {
                ClipboardManager.shared.decrementSmartGroup(name: oldGroup, context: modelContext)
            }
        }
        try? modelContext.save()
        store.refreshSidebarCounts()
    }

    func removeFromGroup(items: [ClipItem]) {
        for item in items {
            guard let name = item.groupName, !name.isEmpty else { continue }
            item.groupName = nil
            ClipboardManager.shared.decrementSmartGroup(name: name, context: modelContext)
        }
        try? modelContext.save()
        store.refreshSidebarCounts()
    }

    func applyTransform(_ action: RuleAction, to item: ClipItem) {
        let processed = AutomationEngine.shared.applyAction(action, to: item.content)
        item.content = processed
        item.displayTitle = ClipItem.buildTitle(content: processed, contentType: item.contentType)
        if action == .stripRichText {
            item.richTextData = nil
            item.richTextType = nil
        }
        ClipItemStore.saveAndNotify(modelContext)
    }

    func fetchEnabledRules() -> [AutomationRule] {
        let descriptor = FetchDescriptor<AutomationRule>(
            predicate: #Predicate { $0.enabled },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func applyRule(_ rule: AutomationRule, to item: ClipItem) {
        let actions = rule.actions
        guard !actions.isEmpty else { return }
        let processed = AutomationEngine.executeActions(actions, on: item.content)
        guard processed != item.content || actions.contains(.stripRichText) else { return }
        item.content = processed
        item.displayTitle = ClipItem.buildTitle(content: processed, contentType: item.contentType)
        if actions.contains(.stripRichText) {
            item.richTextData = nil
            item.richTextType = nil
        }
        ClipItemStore.saveAndNotify(modelContext)
    }

    func deleteItems(_ itemsToDelete: [ClipItem]) {
        guard !itemsToDelete.isEmpty else { return }
        let items = filteredItems
        let idsToDelete = Set(itemsToDelete.map(\.persistentModelID))
        let firstIdx = items.firstIndex { idsToDelete.contains($0.persistentModelID) }
        for del in itemsToDelete {
            if let groupName = del.groupName, !groupName.isEmpty {
                ClipboardManager.shared.decrementSmartGroup(name: groupName, context: modelContext)
            }
            modelContext.delete(del)
        }
        store.removeItems(matching: idsToDelete)
        let remaining = filteredItems
        if let idx = firstIdx, !remaining.isEmpty {
            let nextIdx = min(idx, remaining.count - 1)
            let nextID = remaining[nextIdx].persistentModelID
            selectedItemIDs = [nextID]
            lastNavigatedID = nextID
        } else {
            let firstID = remaining.first?.persistentModelID
            selectedItemIDs = firstID.map { [$0] } ?? []
            lastNavigatedID = firstID
        }
    }

    func handleOpenLink() {
        guard let item = currentItem else { return }
        if item.contentType == .link,
           let url = URL(string: item.content.trimmingCharacters(in: .whitespacesAndNewlines)) {
            NSWorkspace.shared.open(url)
            handleDismiss()
        } else {
            QuickLookHelper.shared.toggle(item: item)
        }
    }

    func handleDismiss() { HotkeyManager.shared.hideQuickPanel() }

    func handleRelayAction() {
        if RelayManager.shared.isActive {
            RelayManager.shared.deactivate()
        } else {
            let items = isMultiSelected ? currentItems : (currentItem.map { [$0] } ?? [])
            let texts = items.compactMap { $0.content.isEmpty ? nil : $0.content }
            guard !texts.isEmpty else { return }
            
            RelayManager.shared.enqueue(texts: texts)
            RelayManager.shared.activate()
            handleDismiss()
        }
    }

    func togglePreview() {
        if QuickLookHelper.shared.isVisible {
            QuickLookHelper.shared.closePreview()
            return
        }
        guard !isMultiSelected, let item = currentItem else { return }
        QuickLookHelper.shared.toggle(item: item)
    }

    var isTargetFinder: Bool {
        clipboardManager.isFinderApp(QuickPanelWindowController.shared.previousApp)
    }

    var canSaveAttachmentToFolder: Bool {
        guard let item = currentItem,
              item.imageData != nil,
              item.contentType != .image else { return false }
        return isTargetFinder
    }

    var canSaveTextToFolder: Bool {
        guard let item = currentItem,
              item.contentType == .text || item.contentType == .code,
              item.imageData == nil else { return false }
        return isTargetFinder
    }

    func handleCmdEnter() {
        guard let item = currentItem else { return }
        // Link → open in browser
        if item.contentType == .link,
           let url = URL(string: item.content.trimmingCharacters(in: .whitespacesAndNewlines)) {
            QuickPanelWindowController.shared.dismiss()
            NSWorkspace.shared.open(url)
        }
        // File-based (including file images) → paste path
        else if isFileBasedItem(item) {
            handlePastePath()
        }
        // Pure text → save to folder if target is Finder
        else if canSaveTextToFolder {
            handlePasteTextToFolder()
        }
        // Text-like types → paste as plain text
        else if [.text, .code, .color, .email, .phone].contains(item.contentType) {
            handlePlainTextPaste(item)
        }
    }

    func handlePlainTextPaste(_ item: ClipItem) {
        markItemsAsRecentlyUsed([item])
        let appToRestore = QuickPanelWindowController.shared.previousApp
        QuickPanelWindowController.shared.dismiss()

        if let app = appToRestore {
            app.activate()
            Task { @MainActor in
                for _ in 0..<20 {
                    try? await Task.sleep(for: .milliseconds(50))
                    if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier { break }
                }
                try? await Task.sleep(for: .milliseconds(50))
                clipboardManager.pasteAsPlainText(item)
            }
        }
    }

    func handlePasteTextToFolder() {
        guard let item = currentItem else { return }
        markItemsAsRecentlyUsed([item])

        guard let folder = clipboardManager.getFinderSelectedFolder() else { return }

        let ext = item.resolvedFileExtension
        guard let savedURL = clipboardManager.saveTextToFolder(item.content, folder: folder, fileExtension: ext) else { return }

        let appToRestore = QuickPanelWindowController.shared.previousApp
        QuickPanelWindowController.shared.dismiss()

        if let app = appToRestore {
            app.activate()
            Task { @MainActor in
                for _ in 0..<20 {
                    try? await Task.sleep(for: .milliseconds(50))
                    if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier { break }
                }
                try? await Task.sleep(for: .milliseconds(100))
                NSWorkspace.shared.selectFile(savedURL.path, inFileViewerRootedAtPath: savedURL.deletingLastPathComponent().path)
            }
        }
    }

    func handlePasteImage() {
        guard let item = currentItem, let imageData = item.imageData else { return }
        markItemsAsRecentlyUsed([item])
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(imageData, forType: .tiff)
        clipboardManager.lastChangeCount = pasteboard.changeCount
        SoundManager.playPaste()

        let appToRestore = QuickPanelWindowController.shared.previousApp
        QuickPanelWindowController.shared.dismiss()

        if let app = appToRestore {
            app.activate()
            Task { @MainActor in
                for _ in 0..<20 {
                    try? await Task.sleep(for: .milliseconds(50))
                    if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier { break }
                }
                try? await Task.sleep(for: .milliseconds(50))
                clipboardManager.simulatePaste()
            }
        }
    }

    func handlePastePath() {
        guard let item = currentItem, isFileBasedItem(item) else { return }
        markItemsAsRecentlyUsed([item])
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        clipboardManager.lastChangeCount = pasteboard.changeCount
        SoundManager.playPaste()

        let appToRestore = QuickPanelWindowController.shared.previousApp
        QuickPanelWindowController.shared.dismiss()

        if let app = appToRestore {
            app.activate()
            Task { @MainActor in
                for _ in 0..<20 {
                    try? await Task.sleep(for: .milliseconds(50))
                    if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier { break }
                }
                try? await Task.sleep(for: .milliseconds(50))
                clipboardManager.simulatePaste()
            }
        }
    }

    func handlePaste(forceNewLine: Bool = false) {
        guard let item = currentItem else { return }
        if canPasteToFinderFolder {
            handlePasteImageToFolder()
        } else if canSaveTextToFolder {
            handlePasteTextToFolder()
        } else {
            QuickPanelWindowController.shared.dismissAndPaste(
                item,
                clipboardManager: clipboardManager,
                addNewLine: forceNewLine
            )
        }
    }

    func handlePasteImageToFolder() {
        guard let item = currentItem, let imageData = item.imageData else {
            // No image data, fallback to normal paste
            if let item = currentItem {
                QuickPanelWindowController.shared.dismissAndPaste(item, clipboardManager: clipboardManager)
            }
            return
        }

        guard let folder = clipboardManager.getFinderSelectedFolder() else {
            // Can't get folder, fallback to paste image
            handlePasteImage()
            return
        }

        markItemsAsRecentlyUsed([item])

        guard let savedURL = clipboardManager.saveImageToFolder(imageData, folder: folder) else {
            // Save failed, fallback to paste image
            handlePasteImage()
            return
        }

        let appToRestore = QuickPanelWindowController.shared.previousApp
        QuickPanelWindowController.shared.dismiss()

        if let app = appToRestore {
            app.activate()
            Task { @MainActor in
                for _ in 0..<20 {
                    try? await Task.sleep(for: .milliseconds(50))
                    if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier { break }
                }
                try? await Task.sleep(for: .milliseconds(100))
                NSWorkspace.shared.selectFile(savedURL.path, inFileViewerRootedAtPath: savedURL.deletingLastPathComponent().path)
            }
        }
    }
}
