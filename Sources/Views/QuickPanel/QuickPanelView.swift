import SwiftUI
import SwiftData
import AppKit

struct QuickPanelView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @Environment(\.modelContext) var modelContext
    @Environment(\.openWindow) var openWindow
    @Environment(\.openSettings) var openSettings
    @AppStorage(QuickPanelStyle.storageKey) var quickPanelStyle = QuickPanelStyle.classic.rawValue
    @ObservedObject var hotkeyManager = HotkeyManager.shared
    @State var store = ClipItemStore()
    @State var searchText = ""
    @State var groupSuggestionIndex = -1
    @State var selectedGroupFilter: String?
    @State var isAppFilter = false
    @State var selectedItemIDs: Set<PersistentIdentifier> = []
    @State var selectedFilter: QuickFilter = .all
    @State var keyMonitor: Any?
    @State var flagsMonitor: Any?
    @FocusState var isSearchFocused: Bool
    @State var lastClickedID: PersistentIdentifier?
    @State var lastClickTime: Date = .distantPast
    @State var lastNavigatedID: PersistentIdentifier?
    @State var selectionAnchor: PersistentIdentifier?
    @State var showAllShortcuts = false
    @State var relaySplitText: String?
    @State var showCopiedToast = false
    @State var showCommandPalette = false
    @State var targetApp: NSRunningApplication?
    @State var isPanelPinned = false
    @State var scrollResetToken = UUID()
    @State var lastSeenFirstItemID: String?
    @State var cachedGroupedItems: [GroupedItem<ClipItem>] = []
    @State var cachedDisplayOrder: [ClipItem] = []
    @State var cachedItemMap: [PersistentIdentifier: ClipItem] = [:]
    @State var cachedIDSet: Set<PersistentIdentifier> = []
    @State var bottomMode: QuickPanelBottomMode = .compact
    @State var keepBottomDetailsMounted = false
    @State var isBottomSearchExpanded = false
    @State var isLiveResizing = false
    @State var frozenBottomCardMetrics: BottomCardLayoutMetrics?
    @State var bottomClipAllowsDirectionalFallback = true
    @State var showBottomOverflowMenu = false
    @State var editingItem: ClipItem?
    @State var editingContent: String = ""

    var filteredItems: [ClipItem] { store.items }

    var groupedItems: [GroupedItem<ClipItem>] { cachedGroupedItems }

    /// Flat list in display order (matches what user sees on screen)
    var displayOrderItems: [ClipItem] { cachedDisplayOrder }

    var defaultItem: ClipItem? {
        cachedDisplayOrder.first
    }

    var panelStyle: QuickPanelStyle {
        QuickPanelStyle(rawValue: quickPanelStyle) ?? .classic
    }

    var isBottomFloatingStyle: Bool {
        panelStyle == .bottomFloating
    }

    var isBottomExpanded: Bool {
        isBottomFloatingStyle && bottomMode == .expanded
    }

    var currentCustomGroupFilterName: String? {
        guard !isAppFilter, let name = selectedGroupFilter else { return nil }
        return store.sidebarCounts.byGroup.contains(where: { $0.name == name }) ? name : nil
    }

    var isBottomSearchCollapsed: Bool {
        isBottomFloatingStyle
        && !isBottomSearchExpanded
        && !isSearchFocused
        && searchText.isEmpty
    }

    var bottomSearchFieldWidth: CGFloat {
        isBottomSearchCollapsed ? QuickPanelBottomTheme.searchHeight : QuickPanelBottomTheme.searchWidth
    }

    var shouldRenderBottomDetails: Bool {
        isBottomExpanded || keepBottomDetailsMounted
    }

    var bottomOverflowMenuSections: [AppMenuSectionDefinition] {
        AppMenuFactory.makeSections(
            hotkeyManager: hotkeyManager,
            clipboardManager: clipboardManager,
            onOpenManager: {
                showBottomOverflowMenu = false
                handleDismiss()
                AppAction.shared.openMainWindow?()
            },
            onOpenQuickPanel: {
                showBottomOverflowMenu = false
                HotkeyManager.shared.toggleQuickPanel()
            },
            onOpenAutomationManager: {
                showBottomOverflowMenu = false
                handleDismiss()
                AppAction.shared.openAutomationManager?()
            },
            onOpenSettings: {
                showBottomOverflowMenu = false
                handleDismiss()
                AppAction.shared.openSettings?()
            }
        )
    }

    func storeAppActions() {
        let hideDock = UserDefaults.standard.bool(forKey: "hideDockIcon")
        AppAction.shared.openMainWindow = { [openWindow] in
            openWindow(id: "main")
            if !hideDock {
                NSApp.setActivationPolicy(.regular)
            }
            NSApp.activate(ignoringOtherApps: true)
        }
        AppAction.shared.openSettings = { [openSettings] in
            if !hideDock {
                NSApp.setActivationPolicy(.regular)
            }
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        AppAction.shared.openAutomationManager = { [openWindow] in
            if !hideDock {
                NSApp.setActivationPolicy(.regular)
            }
            openWindow(id: "automationManager")
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func rebuildGroupedItems() {
        cachedGroupedItems = groupItemsByTime(filteredItems, separatePinned: false)
        cachedDisplayOrder = cachedGroupedItems.flatMap(\.items)
        cachedItemMap = Dictionary(cachedDisplayOrder.map { ($0.persistentModelID, $0) }, uniquingKeysWith: { _, last in last })
        cachedIDSet = Set(cachedItemMap.keys)
    }

    func bottomCardLayoutMetrics(for size: CGSize, freezeForLiveResize: Bool) -> BottomCardLayoutMetrics {
        let horizontalPadding: CGFloat = 10
        let verticalPadding: CGFloat = bottomMode == .compact ? 10 : 12
        let spacing: CGFloat = 12

        let railHeight: CGFloat
        if bottomMode == .compact {
            railHeight = max(size.height - 86, 150)
        } else {
            railHeight = min(max(size.height * 0.31, 228), 300)
        }

        let normalizedRailHeight = freezeForLiveResize
            ? quantizedLiveResizeLength(railHeight, step: bottomMode == .compact ? 14 : 12)
            : railHeight
        let cardSide = max(normalizedRailHeight - verticalPadding * 2, 156)

        return BottomCardLayoutMetrics(
            railHeight: normalizedRailHeight,
            cardWidth: cardSide,
            cardHeight: cardSide,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            spacing: spacing
        )
    }

    func bottomCardLayoutMetrics(for size: CGSize) -> BottomCardLayoutMetrics {
        bottomCardLayoutMetrics(for: size, freezeForLiveResize: isLiveResizing)
    }

    func resolvedBottomCardLayoutMetrics(for size: CGSize) -> BottomCardLayoutMetrics {
        let liveMetrics = bottomCardLayoutMetrics(for: size)
        guard isLiveResizing, let frozen = frozenBottomCardMetrics else {
            return liveMetrics
        }

        return BottomCardLayoutMetrics(
            railHeight: min(frozen.railHeight, liveMetrics.railHeight),
            cardWidth: min(frozen.cardWidth, liveMetrics.cardWidth),
            cardHeight: min(frozen.cardHeight, liveMetrics.cardHeight),
            horizontalPadding: frozen.horizontalPadding,
            verticalPadding: frozen.verticalPadding,
            spacing: frozen.spacing
        )
    }

    /// Single selected ID for backward compat
    var selectedItemID: PersistentIdentifier? {
        selectedItemIDs.count == 1 ? selectedItemIDs.first : selectedItemIDs.first
    }

    var isMultiSelected: Bool { selectedItemIDs.count > 1 }

    var currentItems: [ClipItem] {
        selectedItemIDs.compactMap { cachedItemMap[$0] }
    }

    var currentItem: ClipItem? {
        guard !isMultiSelected else { return nil }
        guard let id = selectedItemIDs.first else { return defaultItem }
        return cachedItemMap[id]
    }

    func selectItem(_ id: PersistentIdentifier, allowsDirectionalFallback: Bool = true) {
        bottomClipAllowsDirectionalFallback = allowsDirectionalFallback
        selectedItemIDs = [id]
        lastNavigatedID = id
    }

    func resetSearchFocusForPresentation() {
        isSearchFocused = !isBottomFloatingStyle
        isBottomSearchExpanded = false
    }

    func restoreSearchFocusIfNeeded() {
        if !isBottomFloatingStyle {
            isSearchFocused = true
        }
    }

    func activateSearchField() {
        guard isBottomFloatingStyle else {
            isSearchFocused = true
            return
        }

        isBottomSearchExpanded = true
        Task { @MainActor in
            await Task.yield()
            isSearchFocused = true
        }
    }

    func syncBottomSearchExpansion() {
        guard isBottomFloatingStyle else {
            isBottomSearchExpanded = false
            return
        }

        isBottomSearchExpanded = isSearchFocused || !searchText.isEmpty
    }

    func moveFocusToSelectionIfNeeded() {
        if isBottomFloatingStyle {
            isSearchFocused = false
        } else {
            isSearchFocused = true
        }
    }

    func bottomClipScrollAnchor(
        for id: PersistentIdentifier,
        previousID: PersistentIdentifier?,
        allowsDirectionalFallback: Bool
    ) -> UnitPoint? {
        QuickPanelSelectionLogic.bottomClipScrollAnchor(
            ids: displayOrderItems.map(\.persistentModelID),
            targetID: id,
            previousID: previousID,
            allowsDirectionalFallback: allowsDirectionalFallback
        )
    }

    func ensureBottomClipVisible(
        id: PersistentIdentifier,
        previousID: PersistentIdentifier?,
        proxy: ScrollViewProxy
    ) {
        let allowsDirectionalFallback = bottomClipAllowsDirectionalFallback
        bottomClipAllowsDirectionalFallback = true

        guard let anchor = bottomClipScrollAnchor(
            for: id,
            previousID: previousID,
            allowsDirectionalFallback: allowsDirectionalFallback
        ) else { return }

        withAnimation(.easeOut(duration: 0.16)) {
            proxy.scrollTo(id, anchor: anchor)
        }
    }

    func handleItemClick(_ id: PersistentIdentifier) {
        let now = Date()
        let isDoubleClick = lastClickedID == id && now.timeIntervalSince(lastClickTime) < 0.3

        if isDoubleClick {
            selectItem(id, allowsDirectionalFallback: false)
            handlePaste()
            lastClickedID = nil
            lastClickTime = .distantPast
            return
        }

        let flags = NSApp.currentEvent?.modifierFlags ?? []
        if flags.contains(.command) {
            toggleItemInSelection(id)
        } else if flags.contains(.shift) {
            extendSelectionTo(id)
        } else {
            selectItem(id, allowsDirectionalFallback: false)
        }
        moveFocusToSelectionIfNeeded()
        syncQuickLookPreviewForSelection()
        lastClickedID = id
        lastClickTime = now
    }

    func syncQuickLookPreviewForSelection() {
        guard QuickLookHelper.shared.isVisible else { return }
        guard !isMultiSelected, let item = currentItem else {
            QuickLookHelper.shared.closePreview()
            return
        }
        QuickLookHelper.shared.preview(item: item)
    }

    func toggleItemInSelection(_ id: PersistentIdentifier) {
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
        }
    }

    func extendSelectionTo(_ id: PersistentIdentifier) {
        let items = displayOrderItems
        guard let lastID = selectedItemIDs.first,
              let lastIdx = items.firstIndex(where: { $0.persistentModelID == lastID }),
              let clickIdx = items.firstIndex(where: { $0.persistentModelID == id }) else {
            selectItem(id)
            return
        }
        let range = min(lastIdx, clickIdx)...max(lastIdx, clickIdx)
        selectedItemIDs = Set(items[range].map(\.persistentModelID))
    }

    var body: some View {
        ZStack(alignment: .top) {
        Group {
            if isBottomFloatingStyle {
                bottomFloatingLayout
            } else {
                classicLayout
            }
        }
        .overlay {
            if showCopiedToast {
                VStack {
                    Spacer()
                    Text(L10n.tr("action.copied"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.75), in: Capsule())
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .padding(.bottom, 50)
                }
                .animation(.easeInOut(duration: 0.2), value: showCopiedToast)
            }
            // Command palette is now shown via popover on the selected row
        }
        if isBottomFloatingStyle && showBottomOverflowMenu {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    showBottomOverflowMenu = false
                }
                .zIndex(20)
        }
        if isBottomFloatingStyle && showBottomOverflowMenu {
            VStack {
                HStack {
                    Spacer(minLength: 0)
                    QuickPanelOverflowMenu(sections: bottomOverflowMenuSections)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 42)
            .padding(.trailing, 16)
            .zIndex(21)
        }
        // Floating group suggestions overlay
        if isShowingSuggestions {
            VStack(spacing: 0) {
                Spacer().frame(height: 48)
                HStack {
                    groupSuggestions
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08)))
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
                        .frame(maxWidth: 260)
                    Spacer()
                }
                .padding(.horizontal, 16)
                Spacer()
            }
            .allowsHitTesting(true)
        }
        } // ZStack
        .onAppear {
            storeAppActions()
            store.configure(modelContext: modelContext)
            rebuildGroupedItems()
            if let id = defaultItem?.persistentModelID { selectedItemIDs = [id]; lastNavigatedID = id }
            installKeyMonitor()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                resetSearchFocusForPresentation()
                prewarmBottomDetailsIfNeeded()
            }
        }
        .onDisappear {
            showBottomOverflowMenu = false
            removeKeyMonitor()
            store.isActive = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickPanelDidShow)) { _ in
            storeAppActions()
            showBottomOverflowMenu = false
            showCommandPalette = false
            searchText = ""
            selectedGroupFilter = nil
            isAppFilter = false
            selectedFilter = .all
            isPanelPinned = false
            isLiveResizing = false
            frozenBottomCardMetrics = nil
            bottomMode = isBottomFloatingStyle ? .compact : .expanded
            if isBottomFloatingStyle {
                QuickPanelWindowController.shared.setBottomFloatingMode(.compact, animated: false)
            }
            store.isActive = true
            store.configure(modelContext: modelContext)
            // Check if new content arrived before resetting
            let latestItemID = store.queryFirstItemID()
            if latestItemID != lastSeenFirstItemID {
                store.resetFilters()
                rebuildGroupedItems()
                scrollResetToken = UUID()
                if let id = cachedDisplayOrder.first?.persistentModelID {
                    selectedItemIDs = [id]
                    lastNavigatedID = id
                }
                lastSeenFirstItemID = latestItemID
            }
            targetApp = QuickPanelWindowController.shared.previousApp
            resetSearchFocusForPresentation()
            prewarmBottomDetailsIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickPanelLiveResizeDidBegin)) { notification in
            guard isBottomFloatingStyle else { return }
            showBottomOverflowMenu = false
            if let panel = notification.object as? NSPanel {
                let contentSize = panel.contentView?.bounds.size ?? panel.frame.size
                frozenBottomCardMetrics = bottomCardLayoutMetrics(for: contentSize, freezeForLiveResize: true)
            }
            isLiveResizing = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickPanelLiveResizeDidEnd)) { _ in
            guard isBottomFloatingStyle else { return }
            isLiveResizing = false
            frozenBottomCardMetrics = nil
        }
        .onChange(of: searchText) {
            groupSuggestionIndex = -1
            if selectedGroupFilter != nil {
                // Group tag is active — search text is just keyword
                store.searchText = searchText
            } else if searchText.hasPrefix(Self.GROUP_SEARCH_PREFIX) {
                if QuickPanelSearchLogic.shouldTreatAsPathQuery(
                    searchText,
                    prefix: Self.GROUP_SEARCH_PREFIX
                ) {
                    // Looks like a path - perform normal search
                    store.groupName = nil
                    store.searchText = searchText
                } else {
                    // Single slash - group selection mode
                    // Typing / for group selection — don't search yet
                    store.searchText = ""
                    store.groupName = nil
                }
            } else {
                store.groupName = nil
                store.searchText = searchText
            }
            syncBottomSearchExpansion()
        }
        .onChange(of: isSearchFocused) {
            syncBottomSearchExpansion()
        }
        .onChange(of: selectedGroupFilter) {
            syncBottomSearchExpansion()
        }
        .onChange(of: selectedFilter) {
            store.pinnedOnly = false
            store.filterType = nil
            switch selectedFilter {
            case .all: break
            case .pinned: store.pinnedOnly = true
            case .type(let t): store.filterType = t
            }
            store.applyFilters()
        }
        .onChange(of: store.items) {
            rebuildGroupedItems()
            guard selectedItemIDs.isEmpty || selectedItemIDs.isDisjoint(with: cachedIDSet) else { return }
            let firstID = defaultItem?.persistentModelID
            if let firstID { selectedItemIDs = [firstID] } else { selectedItemIDs.removeAll() }
            lastNavigatedID = firstID
        }
        .onChange(of: relaySplitText) {
            guard let text = relaySplitText else { return }
            SplitWindowController.shared.show(text: text) { delimiter in
                guard let parts = RelaySplitter.split(text, by: delimiter) else { return }
                RelayManager.shared.enqueue(texts: parts)
                if !RelayManager.shared.isActive {
                    RelayManager.shared.activate()
                }
            }
            relaySplitText = nil
        }
        .onChange(of: editingItem) {
            // 当编辑对话框显示/隐藏时，控制面板的关闭行为
            QuickPanelWindowController.shared.suppressDismiss = editingItem != nil
        }
        .localized()
        .sheet(item: $editingItem) { item in
            VStack(spacing: 0) {
                HStack {
                    Text(L10n.tr("action.edit"))
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Button {
                        cancelEdit()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()

                NativeTextView(
                    text: editingContent,
                    isEditable: true,
                    onTextChange: { editingContent = $0 }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)

                Divider()

                HStack {
                    Spacer()
                    Button(L10n.tr("action.cancel")) {
                        cancelEdit()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    
                    Button(L10n.tr("action.save")) {
                        saveEdit()
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(width: 500, height: 400)
        }
    }
}
