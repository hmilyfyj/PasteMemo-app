import SwiftUI
import SwiftData
import AppKit

extension QuickPanelView {
    @ViewBuilder
    func quickPanelItemContextMenu(for item: ClipItem, itemID: PersistentIdentifier) -> some View {
        if isMultiSelected, selectedItemIDs.contains(itemID) {
            multiSelectionContextMenu(items: currentItems)
        } else {
            singleItemContextMenu(item: item, itemID: itemID)
        }
    }

    @ViewBuilder
    func multiSelectionContextMenu(items: [ClipItem]) -> some View {
        let hasPinned = items.contains(where: \.isPinned)
        Button(hasPinned ? L10n.tr("action.unpin") : L10n.tr("action.pin")) {
            let newValue = !hasPinned
            for item in items { item.isPinned = newValue }
            ClipItemStore.saveAndNotify(modelContext)
        }

        let hasSensitive = items.contains(where: \.isSensitive)
        Button(hasSensitive ? L10n.tr("sensitive.unmarkSensitive") : L10n.tr("sensitive.markSensitive")) {
            let newValue = !hasSensitive
            for item in items { item.isSensitive = newValue }
            ClipItemStore.saveAndNotify(modelContext)
        }

        Button(L10n.tr("action.mergeCopy")) {
            copyItemsToClipboard(items)
        }

        // 多选文件类型：提供"作为文本路径复制"选项
        if items.contains(where: { $0.contentType == .file || $0.contentType == .image || $0.contentType == .video || $0.contentType == .audio || $0.contentType == .document || $0.contentType == .archive || $0.contentType == .application }) {
            Button(L10n.tr("action.copyAsFilePath")) {
                let merged = items.map(\.content).joined(separator: "\n")
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(merged, forType: .string)
                clipboardManager.lastChangeCount = pasteboard.changeCount
                showCopiedToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showCopiedToast = false }
            }
        }

        // 多选文本类型：如果内容是有效文件路径，提供"作为文件粘贴"选项
        if items.allSatisfy({ $0.contentType == .text || $0.contentType == .link }) {
            let validPathItems = items.filter { clipboardManager.canPasteAsFile($0) }
            if !validPathItems.isEmpty {
                Button(L10n.tr("action.pasteAsFile")) {
                    let merged = validPathItems.map(\.content).joined(separator: "\n")
                    let tempItem = ClipItem(content: merged, contentType: .text)
                    _ = clipboardManager.writeAsFileReference(tempItem)
                    showCopiedToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showCopiedToast = false }
                }
            }
        }

        Divider()

        let groupNames = Set(items.compactMap(\.groupName))
        let currentGroup = groupNames.count == 1 ? groupNames.first : nil
        Menu(L10n.tr("action.assignGroup")) {
            ForEach(store.sidebarCounts.byGroup, id: \.name) { group in
                if group.name == currentGroup {
                    Button {
                        // 已在当前分组中，保持菜单状态一致即可。
                    } label: {
                        Label(group.name, systemImage: "checkmark")
                    }
                } else {
                    Button(group.name) {
                        assignToGroup(items: items, name: group.name)
                    }
                }
            }
            if !store.sidebarCounts.byGroup.isEmpty {
                Divider()
            }
            Button(L10n.tr("action.newGroup")) {
                showNewGroupAlert(for: items)
            }
        }

        if items.contains(where: { $0.groupName != nil }) {
            Button(L10n.tr("action.removeFromGroup")) {
                removeFromGroup(items: items)
            }
        }

        Divider()

        Button(L10n.tr("relay.addToQueue")) {
            let texts = items.compactMap(\.content)
            RelayManager.shared.enqueue(texts: texts)
            if !RelayManager.shared.isActive {
                RelayManager.shared.activate()
            }
        }

        Divider()

        Button(L10n.tr("action.delete"), role: .destructive) {
            handleDeleteSelected()
        }
    }

    @ViewBuilder
    func singleItemContextMenu(item: ClipItem, itemID: PersistentIdentifier) -> some View {
        Button(item.isPinned ? L10n.tr("action.unpin") : L10n.tr("action.pin")) {
            item.isPinned.toggle()
            ClipItemStore.saveAndNotify(modelContext)
            selectItem(itemID)
        }

        Button(item.isSensitive ? L10n.tr("sensitive.unmarkSensitive") : L10n.tr("sensitive.markSensitive")) {
            item.isSensitive.toggle()
            ClipItemStore.saveAndNotify(modelContext)
            selectItem(itemID)
        }

        if isEditableType(item) {
            Button(L10n.tr("action.edit")) {
                editingItem = item
                editingContent = item.content
            }
        }

        Button(L10n.tr("action.mergeCopy")) {
            copyItemsToClipboard([item])
            selectItem(itemID)
        }

        // 文件类型：提供"作为文本路径复制"选项
        if item.contentType == .file || item.contentType == .image || item.contentType == .video || item.contentType == .audio || item.contentType == .document || item.contentType == .archive || item.contentType == .application {
            Button(L10n.tr("action.copyAsFilePath")) {
                clipboardManager.writeAsTextPath(item)
                showCopiedToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showCopiedToast = false }
                selectItem(itemID)
            }
        }

        // 文本类型：如果内容是有效文件路径，提供"作为文件粘贴"选项
        if (item.contentType == .text || item.contentType == .link) && clipboardManager.canPasteAsFile(item) {
            Button(L10n.tr("action.pasteAsFile")) {
                _ = clipboardManager.writeAsFileReference(item)
                showCopiedToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showCopiedToast = false }
                selectItem(itemID)
            }
        }

        Divider()

        let currentGroup = item.groupName
        Menu(L10n.tr("action.assignGroup")) {
            ForEach(store.sidebarCounts.byGroup, id: \.name) { group in
                if group.name == currentGroup {
                    Button {
                        // 已在当前分组中，保持菜单状态一致即可。
                    } label: {
                        Label(group.name, systemImage: "checkmark")
                    }
                } else {
                    Button(group.name) {
                        assignToGroup(items: [item], name: group.name)
                        selectItem(itemID)
                    }
                }
            }
            if !store.sidebarCounts.byGroup.isEmpty {
                Divider()
            }
            Button(L10n.tr("action.newGroup")) {
                showNewGroupAlert(for: [item])
                selectItem(itemID)
            }
        }

        if item.groupName != nil {
            Button(L10n.tr("action.removeFromGroup")) {
                removeFromGroup(items: [item])
                selectItem(itemID)
            }
        }

        if item.contentType.isMergeable,
           ProManager.AUTOMATION_ENABLED {
            let manualRules = fetchEnabledRules()
            if !manualRules.isEmpty {
                Divider()
                Menu(L10n.tr("cmd.automation")) {
                    ForEach(manualRules) { rule in
                        Button(rule.isBuiltIn ? L10n.tr(rule.name) : rule.name) {
                            applyRule(rule, to: item)
                        }
                    }
                }
            }
        }

        Divider()

        if !item.content.isEmpty {
            Button(L10n.tr("relay.addToQueue")) {
                RelayManager.shared.enqueue(texts: [item.content])
                if !RelayManager.shared.isActive {
                    RelayManager.shared.activate()
                }
            }

            Button(L10n.tr("relay.splitAndRelay")) {
                relaySplitText = item.content
            }
        }

        Divider()

        Button(L10n.tr("action.copyDebugInfo")) {
            copyDebugInfo(for: item)
        }

        Divider()

        Button(L10n.tr("action.delete"), role: .destructive) {
            deleteItem(item)
        }
    }

    func editGroupInQuickPanel(name: String) {
        isSearchFocused = false
        removeKeyMonitor()
        QuickPanelWindowController.shared.suppressDismiss = true
        
        let descriptor = FetchDescriptor<SmartGroup>(predicate: #Predicate { $0.name == name })
        guard let group = try? modelContext.fetch(descriptor).first else {
            QuickPanelWindowController.shared.suppressDismiss = false
            installKeyMonitor()
            return
        }
        
        let oldName = group.name
        let result = GroupEditorPanel.show(name: group.name, icon: group.icon)
        
        QuickPanelWindowController.shared.suppressDismiss = false
        installKeyMonitor()
        
        guard let result else { return }
        
        group.name = result.name
        group.icon = result.icon
        
        if group.name != oldName {
            let itemDescriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.groupName == oldName })
            if let items = try? modelContext.fetch(itemDescriptor) {
                for item in items { item.groupName = group.name }
            }
            
            if selectedGroupFilter == oldName {
                selectedGroupFilter = group.name
            }
        }
        
        try? modelContext.save()
        store.refreshSidebarCounts()
    }
    
    func changeGroupIconInQuickPanel(name: String) {
        isSearchFocused = false
        removeKeyMonitor()
        QuickPanelWindowController.shared.suppressDismiss = true
        
        let descriptor = FetchDescriptor<SmartGroup>(predicate: #Predicate { $0.name == name })
        guard let group = try? modelContext.fetch(descriptor).first else {
            QuickPanelWindowController.shared.suppressDismiss = false
            installKeyMonitor()
            return
        }
        
        let result = GroupEditorPanel.show(name: group.name, icon: group.icon)
        
        QuickPanelWindowController.shared.suppressDismiss = false
        installKeyMonitor()
        
        guard let result else { return }
        
        group.icon = result.icon
        try? modelContext.save()
        store.refreshSidebarCounts()
    }
    
    func confirmDeleteGroup(name: String) {
        isSearchFocused = false
        removeKeyMonitor()
        QuickPanelWindowController.shared.suppressDismiss = true
        
        let alert = NSAlert()
        alert.messageText = L10n.tr("action.deleteGroup")
        alert.informativeText = L10n.tr("action.deleteGroupConfirm", name)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.tr("action.delete"))
        alert.addButton(withTitle: L10n.tr("action.cancel"))
        
        let shouldDelete = alert.runModal() == .alertFirstButtonReturn
        
        QuickPanelWindowController.shared.suppressDismiss = false
        installKeyMonitor()
        
        guard shouldDelete else { return }
        
        if selectedGroupFilter == name {
            selectedGroupFilter = nil
        }
        
        AppMenuActions.deleteGroup(name: name, context: modelContext)
        store.refreshSidebarCounts()
    }

    @discardableResult
    func showNewGroupAlert(for items: [ClipItem]) -> String? {
        // Release search field focus before showing modal dialog
        isSearchFocused = false
        
        // Remove keyboard monitor to allow modal dialog to receive keyboard input
        removeKeyMonitor()
        
        // 临时阻止面板关闭，因为模态对话框会导致面板失去焦点
        QuickPanelWindowController.shared.suppressDismiss = true
        
        let result = GroupEditorPanel.show()
        
        // 恢复正常的关闭行为
        QuickPanelWindowController.shared.suppressDismiss = false
        
        // Re-install keyboard monitor after modal dialog closes
        installKeyMonitor()
        
        guard let result else { return nil }
        let name = result.name
        let descriptor = FetchDescriptor<SmartGroup>(predicate: #Predicate { $0.name == name })
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.icon = result.icon
        } else {
            let maxOrder = (try? modelContext.fetch(FetchDescriptor<SmartGroup>()))?.map(\.sortOrder).max() ?? -1
            let group = SmartGroup(name: result.name, icon: result.icon, sortOrder: maxOrder + 1)
            modelContext.insert(group)
        }
        try? modelContext.save()
        assignToGroup(items: items, name: result.name)
        return result.name
    }
}
