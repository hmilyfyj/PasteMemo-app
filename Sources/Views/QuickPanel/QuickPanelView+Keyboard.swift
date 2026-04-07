import SwiftUI
import SwiftData
import AppKit

extension QuickPanelView {
    func moveSelection(_ delta: Int, extendSelection: Bool = false) {
        var items = displayOrderItems
        guard !items.isEmpty else { return }
        let cursorID = lastNavigatedID ?? selectedItemIDs.first ?? items.first?.persistentModelID
        guard let currentIdx = items.firstIndex(where: { $0.persistentModelID == cursorID }) else { return }
        let next = currentIdx + delta
        if next < 0 { return }
        if next >= items.count {
            store.loadMore()
            items = displayOrderItems
            if next >= items.count { return }
        }
        let targetID = items[next].persistentModelID
        lastNavigatedID = targetID
        if extendSelection {
            let anchor = selectionAnchor ?? cursorID ?? targetID
            selectionAnchor = anchor
            guard let anchorIdx = items.firstIndex(where: { $0.persistentModelID == anchor }) else { return }
            let range = min(anchorIdx, next)...max(anchorIdx, next)
            selectedItemIDs = Set(items[range].map(\.persistentModelID))
        } else {
            selectedItemIDs = [targetID]
            selectionAnchor = nil
        }
        syncQuickLookPreviewForSelection()
    }

    func setBottomMode(_ newMode: QuickPanelBottomMode, animated: Bool = true) {
        guard isBottomFloatingStyle else { return }
        if newMode == .expanded {
            keepBottomDetailsMounted = true
        }
        bottomMode = newMode
        QuickPanelWindowController.shared.setBottomFloatingMode(newMode, animated: animated)
    }

    func toggleBottomMode() {
        setBottomMode(bottomMode == .compact ? .expanded : .compact)
    }

    func prewarmBottomDetailsIfNeeded() {
        guard isBottomFloatingStyle, !filteredItems.isEmpty, !keepBottomDetailsMounted else { return }
        DispatchQueue.main.async {
            keepBottomDetailsMounted = true
        }
    }

    func installKeyMonitor() {
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            guard HotkeyManager.shared.isQuickPanelVisible else { return event }
            OptionKeyMonitor.shared.isOptionPressed = event.modifierFlags.contains(.option)
            return event
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard HotkeyManager.shared.isQuickPanelVisible else { return event }
            // Let command palette handle keys when it's open
            if showCommandPalette { return event }
            let hasShift = event.modifierFlags.contains(.shift)
            let hasCmd = event.modifierFlags.contains(.command)

            // Auto-focus search field when typing text or numbers
            if !hasCmd && !isSearchFocused {
                if let characters = event.characters, !characters.isEmpty {
                    let character = characters.first!
                    // Only trigger for letters and digits, exclude space and other special keys
                    if character.isLetter || character.isNumber {
                        // Close QuickLook preview if visible
                        if QuickLookHelper.shared.isVisible {
                            QuickLookHelper.shared.closePreview()
                        }
                        // Add the character to search text and activate search field
                        searchText += String(character)
                        activateSearchField(placeCursorAtEnd: true)
                        return nil
                    }
                }
            }

            // Group suggestion keyboard navigation
            if isShowingSuggestions {
                let total = totalSuggestionCount
                switch Int(event.keyCode) {
                case 125: // Down
                    groupSuggestionIndex = (groupSuggestionIndex + 1) % total
                    return nil
                case 126: // Up
                    groupSuggestionIndex = groupSuggestionIndex <= 0 ? total - 1 : groupSuggestionIndex - 1
                    return nil
                case 36: // Enter
                    if groupSuggestionIndex >= 0, groupSuggestionIndex < total {
                        let groups = currentSuggestionGroups
                        let apps = currentSuggestionApps
                        if groupSuggestionIndex < groups.count {
                            let g = groups[groupSuggestionIndex]
                            selectSuggestion(.group(name: g.name, icon: g.icon, count: g.count))
                        } else {
                            let a = apps[groupSuggestionIndex - groups.count]
                            selectSuggestion(.app(name: a.name, count: a.count))
                        }
                        return nil
                    }
                default: break
                }
            }

            if Int(event.keyCode) == 53,
               QuickLookHelper.shared.isVisible {
                QuickLookHelper.shared.closePreview()
                return nil
            }

            if let intent = QuickPanelKeyboardRouter.intent(
                style: panelStyle,
                bottomMode: bottomMode,
                keyCode: Int(event.keyCode),
                hasCommand: hasCmd,
                suggestionVisible: isShowingSuggestions,
                searchFocused: isSearchFocused
            ) {
                switch intent {
                case .moveSelection(let delta):
                    moveSelection(delta, extendSelection: hasShift)
                case .switchType(let delta):
                    switchType(delta)
                case .toggleBottomMode:
                    toggleBottomMode()
                case .collapseOrDismiss:
                    setBottomMode(.compact)
                case .focusSearch:
                    activateSearchField()
                case .togglePreview:
                    togglePreview()
                }
                return nil
            }

            switch Int(event.keyCode) {
                case 126 where !isSearchFocused: moveSelection(-1, extendSelection: hasShift); return nil
            case 125 where !isSearchFocused: moveSelection(1, extendSelection: hasShift); return nil
            case 123 where !isSearchFocused: switchType(-1); return nil
            case 124 where !isSearchFocused: switchType(1); return nil
            case 48 where !isSearchFocused: switchType(hasShift ? -1 : 1); return nil  // Tab / Shift+Tab
            case 13: // Cmd+W
                if hasCmd { handleDismiss(); return nil }
                return event
            case 53:
                if isShowingSuggestions {
                    searchText = ""
                    groupSuggestionIndex = -1
                    return nil
                }
                if QuickLookHelper.shared.isVisible {
                    QuickLookHelper.shared.closePreview()
                    return nil
                }
                handleDismiss(); return nil
            case 40: // Cmd+K
                if hasCmd {
                    showCommandPalette.toggle()
                    if showCommandPalette { isSearchFocused = false }
                    return nil
                }
                return event
            case 43: // Cmd+,
                if hasCmd {
                    handleDismiss()
                    AppAction.shared.openSettings?()
                    return nil
                }
                return event
            case 3: // Cmd+F
                if hasCmd {
                    activateSearchField()
                    return nil
                }
                return event
            case 8: // Cmd+C
                if hasCmd {
                    // Check if preview area has text selected
                    if let textView = event.window?.firstResponder as? NSTextView,
                       textView.selectedRange().length > 0 {
                        return event // let system copy selected text
                    }
                    let items = isMultiSelected ? currentItems : (currentItem.map { [$0] } ?? [])
                    if !items.isEmpty { copyItemsToClipboard(items) }
                    return nil
                }
                return event
            case 51:
                if hasCmd {
                    if isSearchFocused, !searchText.isEmpty { return event }
                    handleDeleteSelected(); return nil
                }
                if isSearchFocused, searchText.isEmpty, selectedGroupFilter != nil {
                    clearGroupFilter()
                    return nil
                }
                return event
            case 31:
                if hasCmd { handleOpenLink(); return nil }
                return event
            case 36:
                // Let IME confirm its candidate before handling Enter
                if let textView = event.window?.firstResponder as? NSTextView,
                   textView.hasMarkedText() {
                    return event
                }
                if isMultiSelected {
                    handleMultiPaste(asPlainText: hasCmd, forceNewLine: hasShift)
                } else if hasCmd {
                    handleCmdEnter()
                } else if hasShift {
                    handlePaste(forceNewLine: true)
                } else {
                    handlePaste()
                }
                return nil
            default:
                if hasCmd, let digit = Self.digitKeyMap[Int(event.keyCode)] {
                    handleShortcutPaste(index: digit)
                    return nil
                }
                return event
            }
        }
    }

    /// Maps macOS key codes to digit values 1~9.
    static let digitKeyMap: [Int: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5,
        22: 6, 26: 7, 28: 8, 25: 9,
    ]

    var availableContentTypes: [ClipContentType] { store.availableTypes }

    func switchType(_ delta: Int) {
        let types = availableContentTypes
        let allFilters: [QuickFilter] = [.pinned, .all] + types.map { .type($0) }

        if let idx = allFilters.firstIndex(of: selectedFilter) {
            let newIdx = (idx + delta + allFilters.count) % allFilters.count
            selectedFilter = allFilters[newIdx]
        } else {
            selectedFilter = delta > 0 ? allFilters.first! : allFilters.last!
        }
    }

    func removeKeyMonitor() {
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor); keyMonitor = nil }
        if let monitor = flagsMonitor { NSEvent.removeMonitor(monitor); flagsMonitor = nil }
        OptionKeyMonitor.shared.isOptionPressed = false
    }

    /// Returns 1-based shortcut index (1~9) for the item, or nil if beyond top 9.
    func shortcutIndex(for item: ClipItem) -> Int? {
        guard let first9 = cachedDisplayOrder.prefix(9).firstIndex(where: { $0.persistentModelID == item.persistentModelID }) else { return nil }
        return first9 + 1
    }

    func handleShortcutPaste(index: Int) {
        let items = displayOrderItems
        guard index >= 1, index <= 9, index <= items.count else { return }
        let target = items[index - 1]
        selectItem(target.persistentModelID)
        handlePaste()
    }
}
