import SwiftUI
import SwiftData
import Quartz

private enum QuickFilter: Equatable {
    case all
    case pinned
    case type(ClipContentType)
}

private let PANEL_WIDTH: CGFloat = 750
private let PANEL_HEIGHT: CGFloat = 510
private let LIST_WIDTH: CGFloat = 340

private struct BottomCardLayoutMetrics {
    let railHeight: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let spacing: CGFloat
}

struct QuickPanelView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @Environment(\.modelContext) private var modelContext
    @AppStorage(QuickPanelStyle.storageKey) private var quickPanelStyle = QuickPanelStyle.classic.rawValue
    @State private var store = ClipItemStore()
    @State private var searchText = ""
    @State private var groupSuggestionIndex = -1
    @State private var selectedGroupFilter: String?
    @State private var isAppFilter = false
    @State private var selectedItemIDs: Set<PersistentIdentifier> = []
    @State private var selectedFilter: QuickFilter = .all
    @State private var keyMonitor: Any?
    @State private var flagsMonitor: Any?
    @FocusState private var isSearchFocused: Bool
    @State private var lastClickedID: PersistentIdentifier?
    @State private var lastClickTime: Date = .distantPast
    @State private var lastNavigatedID: PersistentIdentifier?
    @State private var selectionAnchor: PersistentIdentifier?
    @State private var showAllShortcuts = false
    @State private var relaySplitText: String?
    @State private var showCopiedToast = false
    @State private var showCommandPalette = false
    @State private var targetApp: NSRunningApplication?
    @State private var isPanelPinned = false
    @State private var scrollResetToken = UUID()
    @State private var lastSeenFirstItemID: String?
    @State private var cachedGroupedItems: [GroupedItem<ClipItem>] = []
    @State private var cachedDisplayOrder: [ClipItem] = []
    @State private var cachedItemMap: [PersistentIdentifier: ClipItem] = [:]
    @State private var cachedIDSet: Set<PersistentIdentifier> = []
    @State private var bottomMode: QuickPanelBottomMode = .compact
    @State private var keepBottomDetailsMounted = false
    @State private var isBottomSearchExpanded = false

    private var filteredItems: [ClipItem] { store.items }

    private var groupedItems: [GroupedItem<ClipItem>] { cachedGroupedItems }

    /// Flat list in display order (matches what user sees on screen)
    private var displayOrderItems: [ClipItem] { cachedDisplayOrder }

    private var defaultItem: ClipItem? {
        cachedDisplayOrder.first
    }

    private var panelStyle: QuickPanelStyle {
        QuickPanelStyle(rawValue: quickPanelStyle) ?? .classic
    }

    private var isBottomFloatingStyle: Bool {
        panelStyle == .bottomFloating
    }

    private var isBottomExpanded: Bool {
        isBottomFloatingStyle && bottomMode == .expanded
    }

    private var currentCustomGroupFilterName: String? {
        guard !isAppFilter, let name = selectedGroupFilter else { return nil }
        return store.sidebarCounts.byGroup.contains(where: { $0.name == name }) ? name : nil
    }

    private var isBottomSearchCollapsed: Bool {
        isBottomFloatingStyle
        && !isBottomSearchExpanded
        && !isSearchFocused
        && searchText.isEmpty
        && selectedGroupFilter == nil
    }

    private var bottomSearchFieldWidth: CGFloat {
        isBottomSearchCollapsed ? QuickPanelBottomTheme.searchHeight : QuickPanelBottomTheme.searchWidth
    }

    private var shouldRenderBottomDetails: Bool {
        isBottomExpanded || keepBottomDetailsMounted
    }

    private func rebuildGroupedItems() {
        cachedGroupedItems = groupItemsByTime(filteredItems, separatePinned: false)
        cachedDisplayOrder = cachedGroupedItems.flatMap(\.items)
        cachedItemMap = Dictionary(cachedDisplayOrder.map { ($0.persistentModelID, $0) }, uniquingKeysWith: { _, last in last })
        cachedIDSet = Set(cachedItemMap.keys)
    }

    /// Single selected ID for backward compat
    private var selectedItemID: PersistentIdentifier? {
        selectedItemIDs.count == 1 ? selectedItemIDs.first : selectedItemIDs.first
    }

    private var isMultiSelected: Bool { selectedItemIDs.count > 1 }

    private var currentItems: [ClipItem] {
        selectedItemIDs.compactMap { cachedItemMap[$0] }
    }

    private var currentItem: ClipItem? {
        guard !isMultiSelected else { return nil }
        guard let id = selectedItemIDs.first else { return defaultItem }
        return cachedItemMap[id]
    }

    private func selectItem(_ id: PersistentIdentifier) {
        selectedItemIDs = [id]
        lastNavigatedID = id
    }

    private func resetSearchFocusForPresentation() {
        isSearchFocused = !isBottomFloatingStyle
        isBottomSearchExpanded = false
    }

    private func restoreSearchFocusIfNeeded() {
        if !isBottomFloatingStyle {
            isSearchFocused = true
        }
    }

    private func activateSearchField() {
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

    private func syncBottomSearchExpansion() {
        guard isBottomFloatingStyle else {
            isBottomSearchExpanded = false
            return
        }

        isBottomSearchExpanded = isSearchFocused || !searchText.isEmpty || selectedGroupFilter != nil
    }

    private func moveFocusToSelectionIfNeeded() {
        if isBottomFloatingStyle {
            isSearchFocused = false
        } else {
            isSearchFocused = true
        }
    }

    private func handleItemClick(_ id: PersistentIdentifier) {
        let now = Date()
        let isDoubleClick = lastClickedID == id && now.timeIntervalSince(lastClickTime) < 0.3

        if isDoubleClick {
            selectItem(id)
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
            selectItem(id)
        }
        moveFocusToSelectionIfNeeded()
        syncQuickLookPreviewForSelection()
        lastClickedID = id
        lastClickTime = now
    }

    private func syncQuickLookPreviewForSelection() {
        guard QuickLookHelper.shared.isVisible else { return }
        guard !isMultiSelected, let item = currentItem else {
            QuickLookHelper.shared.closePreview()
            return
        }
        QuickLookHelper.shared.preview(item: item)
    }

    private func toggleItemInSelection(_ id: PersistentIdentifier) {
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
        }
    }

    private func extendSelectionTo(_ id: PersistentIdentifier) {
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
            removeKeyMonitor()
            store.isActive = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickPanelDidShow)) { _ in
            showCommandPalette = false
            searchText = ""
            selectedGroupFilter = nil
            isAppFilter = false
            selectedFilter = .all
            isPanelPinned = false
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
        .onChange(of: searchText) {
            groupSuggestionIndex = -1
            if selectedGroupFilter != nil {
                // Group tag is active — search text is just keyword
                store.searchText = searchText
            } else if searchText.hasPrefix(Self.GROUP_SEARCH_PREFIX) {
                // Typing / for group selection — don't search yet
                store.searchText = ""
                store.groupName = nil
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
        .localized()
    }

    private var classicLayout: some View {
        VStack(spacing: 0) {
            searchBar
            tabBar
            Divider().opacity(0.3)
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                HStack(spacing: 0) {
                    clipList
                    Divider().opacity(0.3)
                    previewPane
                }
            }
            Divider().opacity(0.3)
            footerBar
        }
        .frame(minWidth: 500, minHeight: 350)
    }

    private var bottomFloatingLayout: some View {
        GeometryReader { proxy in
            let metrics = bottomCardLayoutMetrics(for: proxy.size)

            VStack(spacing: 12) {
                bottomHeader
                if filteredItems.isEmpty {
                    bottomEmptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .quickPanelBottomSection()
                } else {
                    bottomClipRail(metrics: metrics)
                        .frame(height: metrics.railHeight)

                    if shouldRenderBottomDetails {
                        bottomDetailsSection
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: isBottomExpanded ? .infinity : 0,
                                alignment: .top
                            )
                            .opacity(isBottomExpanded ? 1 : 0)
                            .allowsHitTesting(isBottomExpanded)
                            .accessibilityHidden(!isBottomExpanded)
                            .clipped()
                    }
                }
            }
            .padding(QuickPanelBottomTheme.contentInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .quickPanelBottomShell()
            .padding(.horizontal, QuickPanelBottomTheme.shellInset)
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
        .frame(
            minWidth: QuickPanelBottomGeometry.minimumWidth,
            idealWidth: QuickPanelBottomGeometry.minimumWidth,
            maxWidth: .infinity,
            minHeight: bottomMode == .compact ? QuickPanelBottomGeometry.compactHeight : QuickPanelBottomGeometry.expandedHeight,
            maxHeight: .infinity
        )
    }

    private func bottomCardLayoutMetrics(for size: CGSize) -> BottomCardLayoutMetrics {
        let horizontalPadding: CGFloat = 10
        let verticalPadding: CGFloat = bottomMode == .compact ? 10 : 12
        let spacing: CGFloat = 12

        let railHeight: CGFloat
        if bottomMode == .compact {
            railHeight = max(size.height - 86, 150)
        } else {
            railHeight = min(max(size.height * 0.31, 228), 300)
        }

        let cardSide = max(railHeight - verticalPadding * 2, 156)

        return BottomCardLayoutMetrics(
            railHeight: railHeight,
            cardWidth: cardSide,
            cardHeight: cardSide,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            spacing: spacing
        )
    }

    private var bottomDetailsSection: some View {
        VStack(spacing: 8) {
            previewPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            compactFooterBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .quickPanelBottomSection()
    }

    // MARK: - Search

    private static let GROUP_SEARCH_PREFIX = "/"

    private enum SuggestionItem: Equatable {
        case group(name: String, icon: String, count: Int)
        case app(name: String, count: Int)

        static func == (lhs: SuggestionItem, rhs: SuggestionItem) -> Bool {
            switch (lhs, rhs) {
            case (.group(let a, _, _), .group(let b, _, _)): return a == b
            case (.app(let a, _), .app(let b, _)): return a == b
            default: return false
            }
        }
    }

    private var isShowingSuggestions: Bool {
        guard selectedGroupFilter == nil else { return false }
        guard searchText.hasPrefix(Self.GROUP_SEARCH_PREFIX) else { return false }
        return !currentSuggestionGroups.isEmpty || !currentSuggestionApps.isEmpty
    }

    private var currentSuggestionGroups: [(name: String, icon: String, count: Int)] {
        guard searchText.hasPrefix(Self.GROUP_SEARCH_PREFIX) else { return [] }
        let query = String(searchText.dropFirst()).trimmingCharacters(in: .whitespaces).lowercased()
        // Hide if exact match on group
        return store.sidebarCounts.byGroup
            .filter { group in
                query.isEmpty || group.name.lowercased().contains(query)
            }
            .map { group in
                (name: group.name, icon: group.icon, count: group.count)
            }
    }

    private var currentSuggestionApps: [(name: String, count: Int)] {
        guard searchText.hasPrefix(Self.GROUP_SEARCH_PREFIX) else { return [] }
        let query = String(searchText.dropFirst()).trimmingCharacters(in: .whitespaces).lowercased()
        let apps = store.sourceApps
            .filter { !$0.isEmpty }
            .compactMap { name -> (name: String, count: Int)? in
                let count = store.sidebarCounts.byApp[name] ?? 0
                guard count > 0 else { return nil }
                guard query.isEmpty || name.lowercased().contains(query) else { return nil }
                return (name: name, count: count)
            }
            .sorted { $0.count > $1.count }
        return query.isEmpty ? Array(apps.prefix(5)) : apps
    }

    private var totalSuggestionCount: Int {
        currentSuggestionGroups.count + currentSuggestionApps.count
    }

    @ViewBuilder
    private var groupSuggestions: some View {
        let groups = currentSuggestionGroups
        let apps = currentSuggestionApps
        if !groups.isEmpty || !apps.isEmpty {
            VStack(spacing: 0) {
                if !groups.isEmpty {
                    suggestionSectionHeader(L10n.tr("filter.groups"))
                    ForEach(Array(groups.enumerated()), id: \.element.name) { idx, group in
                        suggestionRow(
                            icon: group.icon, name: group.name, count: group.count,
                            isSelected: idx == groupSuggestionIndex
                        ) {
                            selectSuggestion(.group(name: group.name, icon: group.icon, count: group.count))
                        }
                    }
                }
                if !apps.isEmpty {
                    if !groups.isEmpty { Divider().padding(.vertical, 2) }
                    suggestionSectionHeader(L10n.tr("filter.apps"))
                    let offset = groups.count
                    ForEach(Array(apps.enumerated()), id: \.element.name) { idx, app in
                        suggestionRow(
                            icon: "app.dashed", appName: app.name, name: app.name, count: app.count,
                            isSelected: (offset + idx) == groupSuggestionIndex
                        ) {
                            selectSuggestion(.app(name: app.name, count: app.count))
                        }
                    }
                }
            }
        }
    }

    private func suggestionSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }

    private func suggestionRow(icon: String, appName: String? = nil, name: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let appName, let nsIcon = appIcon(forBundleID: nil, name: appName) {
                    Image(nsImage: nsIcon)
                        .resizable()
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .frame(width: 18)
                }
                Text(name)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        isSelected ? Color.white.opacity(0.2) : Color.primary.opacity(0.08),
                        in: Capsule()
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    private func selectSuggestion(_ item: SuggestionItem) {
        searchText = ""
        groupSuggestionIndex = -1
        switch item {
        case .group(let name, _, _):
            selectedGroupFilter = name
            isAppFilter = false
            store.groupName = name
            store.sourceApp = nil
        case .app(let name, _):
            selectedGroupFilter = name
            isAppFilter = true
            store.groupName = nil
            store.sourceApp = .named(name)
        }
        store.searchText = ""
        store.applyFilters()
    }

    private func clearGroupFilter() {
        selectedGroupFilter = nil
        store.groupName = nil
        store.sourceApp = nil
        store.applyFilters()
    }

    private func applyCustomGroupFilter(_ name: String?) {
        if searchText.hasPrefix(Self.GROUP_SEARCH_PREFIX) {
            searchText = ""
            store.searchText = ""
        }
        guard let name else {
            clearGroupFilter()
            return
        }
        selectedGroupFilter = name
        isAppFilter = false
        store.groupName = name
        store.sourceApp = nil
        store.applyFilters()
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18))
                .foregroundStyle(.tertiary)

            if let filterName = selectedGroupFilter {
                let groupIcon = store.sidebarCounts.byGroup.first { $0.name == filterName }?.icon ?? "folder"
                HStack(spacing: 4) {
                    if isAppFilter, let nsIcon = appIcon(forBundleID: nil, name: filterName) {
                        Image(nsImage: nsIcon)
                            .resizable()
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: isAppFilter ? "app.dashed" : groupIcon)
                            .font(.system(size: 10))
                    }
                    Text(filterName)
                        .font(.system(size: 12))
                    Button {
                        clearGroupFilter()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor, in: Capsule())
                .foregroundStyle(.white)
            }

            TextField(L10n.tr("quick.search"), text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($isSearchFocused)

            if !searchText.isEmpty || selectedGroupFilter != nil {
                Button { searchText = ""; clearGroupFilter(); if let id = defaultItem?.persistentModelID { selectedItemIDs = [id] } } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.quaternary)
                }
                .buttonStyle(.plain)
            }

            Button {
                isPanelPinned.toggle()
                QuickPanelWindowController.shared.isPinned = isPanelPinned
            } label: {
                Image(systemName: isPanelPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(height: 20)
                    .padding(.horizontal, 6)
                    .background(isPanelPinned ? Color.primary.opacity(0.05) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isPanelPinned ? L10n.tr("quickPanel.unpin") : L10n.tr("quickPanel.pin"))

            Text("\(store.totalCount)")
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(height: 20)
                .padding(.horizontal, 6)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }

    private var bottomHeader: some View {
        ViewThatFits(in: .horizontal) {
            bottomHeaderSingleRow
            bottomHeaderCompactSingleRow
        }
    }

    private var bottomHeaderSingleRow: some View {
        ZStack {
            HStack(spacing: 10) {
                bottomInlineFilterBar
                    .frame(minWidth: 280, idealWidth: 360, maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(2)

                bottomHeaderTrailingControls
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            bottomHeaderCenterCluster
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var bottomHeaderCompactSingleRow: some View {
        HStack(spacing: 10) {
            bottomInlineFilterBar
                .frame(minWidth: 180, idealWidth: 240, maxWidth: 320, alignment: .leading)
                .layoutPriority(2)

            bottomSearchField
                .frame(
                    minWidth: bottomSearchFieldWidth,
                    idealWidth: bottomSearchFieldWidth,
                    maxWidth: bottomSearchFieldWidth,
                    alignment: .center
                )
                .layoutPriority(1)

            bottomCustomGroupToolbar
                .frame(minWidth: 140, idealWidth: 220, maxWidth: 320, alignment: .leading)
                .layoutPriority(1)

            bottomModeToggleIconButton
            bottomPinButton
            bottomCountBadge
        }
    }

    private var bottomHeaderTrailingControls: some View {
        HStack(spacing: 8) {
            bottomTargetAppBadge
            bottomModeToggleButton
            bottomPinButton
            bottomCountBadge
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var bottomHeaderCenterCluster: some View {
        HStack(spacing: 10) {
            bottomSearchField
                .frame(
                    minWidth: bottomSearchFieldWidth,
                    idealWidth: bottomSearchFieldWidth,
                    maxWidth: bottomSearchFieldWidth,
                    alignment: .center
                )

            bottomCustomGroupToolbar
                .frame(minWidth: 220, idealWidth: 340, maxWidth: 520, alignment: .leading)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var bottomSearchField: some View {
        Group {
            if isBottomSearchCollapsed {
                Button {
                    activateSearchField()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: QuickPanelBottomTheme.searchHeight, height: QuickPanelBottomTheme.searchHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L10n.tr("quick.search"))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(QuickPanelBottomTheme.tertiaryText)

                    if let filterName = selectedGroupFilter, currentCustomGroupFilterName == nil {
                        HStack(spacing: 4) {
                            Text(filterName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                            Button {
                                clearGroupFilter()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(QuickPanelBottomTheme.accentBlue, in: Capsule())
                    }

                    TextField(L10n.tr("quick.search"), text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13.5, weight: .medium))
                        .focused($isSearchFocused)
                        .foregroundStyle(.white.opacity(0.95))

                    if !searchText.isEmpty || selectedGroupFilter != nil {
                        Button {
                            searchText = ""
                            clearGroupFilter()
                            if let id = defaultItem?.persistentModelID { selectedItemIDs = [id] }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: QuickPanelBottomTheme.searchHeight)
                .background(QuickPanelBottomTheme.controlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(QuickPanelBottomTheme.thinStroke, lineWidth: 1)
                )
            }
        }
        .animation(.easeInOut(duration: 0.16), value: isBottomSearchCollapsed)
    }

    // MARK: - Tabs

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                badge(L10n.tr("filter.pinned"), isActive: selectedFilter == .pinned) {
                    selectedFilter = selectedFilter == .pinned ? .all : .pinned
                    restoreSearchFocusIfNeeded()
                }
                badge(L10n.tr("filter.all"), isActive: selectedFilter == .all) {
                    selectedFilter = .all
                    restoreSearchFocusIfNeeded()
                }
                ForEach(availableContentTypes, id: \.self) { type in
                    badge(type.label, isActive: selectedFilter == .type(type)) {
                        selectedFilter = selectedFilter == .type(type) ? .all : .type(type)
                        restoreSearchFocusIfNeeded()
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
        }
    }

    private var bottomInlineFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                bottomFilterBadge(L10n.tr("filter.pinned"), isActive: selectedFilter == .pinned) {
                    selectedFilter = selectedFilter == .pinned ? .all : .pinned
                    restoreSearchFocusIfNeeded()
                }
                bottomFilterBadge(L10n.tr("filter.all"), isActive: selectedFilter == .all) {
                    selectedFilter = .all
                    restoreSearchFocusIfNeeded()
                }
                ForEach(availableContentTypes, id: \.self) { type in
                    bottomFilterBadge(type.label, isActive: selectedFilter == .type(type)) {
                        selectedFilter = selectedFilter == .type(type) ? .all : .type(type)
                        restoreSearchFocusIfNeeded()
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 1)
        }
        .frame(minWidth: 200, idealWidth: 340, maxWidth: 460, minHeight: 28, maxHeight: 28)
    }

    private var bottomCustomGroupToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                bottomGroupToolbarChip(
                    title: L10n.tr("filter.all"),
                    systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    tint: .white.opacity(0.72),
                    isSelected: currentCustomGroupFilterName == nil && !isAppFilter
                ) {
                    clearGroupFilter()
                    restoreSearchFocusIfNeeded()
                }

                ForEach(store.sidebarCounts.byGroup, id: \.name) { group in
                    bottomGroupToolbarChip(
                        title: group.name,
                        systemImage: group.icon,
                        tint: QuickPanelBottomTheme.groupTintColor(name: group.name, preferredHex: group.color),
                        isSelected: currentCustomGroupFilterName == group.name
                    ) {
                        applyCustomGroupFilter(group.name)
                        restoreSearchFocusIfNeeded()
                    }
                }

                Button {
                    if let name = showNewGroupAlert(for: []) {
                        applyCustomGroupFilter(name)
                    }
                    restoreSearchFocusIfNeeded()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 28, height: 28)
                        .background(QuickPanelBottomTheme.toolbarChipFill, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help(L10n.tr("action.newGroup"))
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28, alignment: .leading)
    }

    private func bottomGroupToolbarChip(
        title: String,
        systemImage: String,
        tint: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : tint)
                    .frame(width: 14)

                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.84))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(
                isSelected ? QuickPanelBottomTheme.accentBlue : QuickPanelBottomTheme.toolbarChipFill,
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.07),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var bottomTargetAppBadge: some View {
        if let app = targetApp, let name = app.localizedName {
            HStack(spacing: 5) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 13, height: 13)
                }
                Text(L10n.tr("quick.pasteToApp", name))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(QuickPanelBottomTheme.secondaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(QuickPanelBottomTheme.mutedFill, in: Capsule())
            .frame(maxWidth: 200, alignment: .leading)
            .layoutPriority(0.4)
        }
    }

    private var bottomModeToggleButton: some View {
        Button {
            toggleBottomMode()
        } label: {
            Label(
                bottomMode == .compact ? L10n.tr("quick.expandDetails") : L10n.tr("quick.collapseDetails"),
                systemImage: bottomMode == .compact ? "rectangle.expand.vertical" : "rectangle.compress.vertical"
            )
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(QuickPanelBottomTheme.controlFill, in: Capsule())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    private var bottomModeToggleIconButton: some View {
        Button {
            toggleBottomMode()
        } label: {
            Image(systemName: bottomMode == .compact ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 28, height: 24)
                .background(QuickPanelBottomTheme.controlFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(bottomMode == .compact ? L10n.tr("quick.expandDetails") : L10n.tr("quick.collapseDetails"))
    }

    private var bottomPinButton: some View {
        Button {
            isPanelPinned.toggle()
            QuickPanelWindowController.shared.isPinned = isPanelPinned
        } label: {
            Image(systemName: isPanelPinned ? "pin.fill" : "pin")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 24, height: 24)
                .background(
                    isPanelPinned ? QuickPanelBottomTheme.controlFill.opacity(1.3) : QuickPanelBottomTheme.mutedFill,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .help(isPanelPinned ? L10n.tr("quickPanel.unpin") : L10n.tr("quickPanel.pin"))
    }

    private var bottomCountBadge: some View {
        Text("\(store.totalCount)")
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .foregroundStyle(.white.opacity(0.72))
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(QuickPanelBottomTheme.mutedFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func badge(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: isActive ? .medium : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .foregroundStyle(isActive ? .white : Color(nsColor: .secondaryLabelColor))
                .background(
                    isActive ? Color.accentColor : Color.primary.opacity(0.06),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    private func bottomFilterBadge(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .white : .white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    isActive ? QuickPanelBottomTheme.accentBlue : QuickPanelBottomTheme.mutedFill,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(isActive ? 0 : 0.05))
                )
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    // MARK: - List

    private var clipList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groupedItems, id: \.group) { group in
                            Text(group.group.label)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.top, 6)
                                .padding(.bottom, 2)
                                .id("group_\(group.group.rawValue)")

                            ForEach(group.items) { item in
                                let itemID = item.persistentModelID
                                let shortcutIdx = shortcutIndex(for: item)
                                QuickClipRow(item: item, isSelected: selectedItemIDs.contains(itemID), shortcutIndex: shortcutIdx, searchText: searchText)
                                    .id(itemID)
                                    .contentShape(Rectangle())
                                    .popover(
                                        isPresented: Binding(
                                            get: { showCommandPalette && selectedItemIDs.contains(itemID) && (lastNavigatedID ?? selectedItemIDs.first) == itemID },
                                            set: { if !$0 { showCommandPalette = false; restoreSearchFocusIfNeeded() } }
                                        ),
                                        arrowEdge: .trailing
                                    ) {
                                        CommandPaletteContent(
                                            item: item,
                                            isMultiSelected: isMultiSelected,
                                            onAction: { handleCommandAction($0) },
                                            onDismiss: { showCommandPalette = false; restoreSearchFocusIfNeeded() }
                                        )
                                    }
                                    .onAppear {
                                        if item.id == filteredItems.last?.id { store.loadMore() }
                                    }
                                    .onTapGesture {
                                        handleItemClick(itemID)
                                    }
                                    .contextMenu {
                                        quickPanelItemContextMenu(for: item, itemID: itemID)
                                    }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                }
                .onChange(of: lastNavigatedID) {
                guard let id = lastNavigatedID else { return }
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(id)
                }
            }
                .onChange(of: selectedFilter) {
                if let firstGroup = cachedGroupedItems.first {
                    proxy.scrollTo("group_\(firstGroup.group.rawValue)", anchor: .top)
                }
            }
            .id(scrollResetToken)
        }
        .frame(width: LIST_WIDTH)
    }

    private func bottomClipRail(metrics: BottomCardLayoutMetrics) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: metrics.spacing) {
                    ForEach(displayOrderItems) { item in
                        let itemID = item.persistentModelID
                        QuickClipCard(
                            item: item,
                            isSelected: selectedItemIDs.contains(itemID),
                            shortcutIndex: shortcutIndex(for: item),
                            cardWidth: metrics.cardWidth,
                            cardHeight: metrics.cardHeight
                        )
                        .id(itemID)
                        .popover(
                            isPresented: Binding(
                                get: { showCommandPalette && selectedItemIDs.contains(itemID) && (lastNavigatedID ?? selectedItemIDs.first) == itemID },
                                set: { if !$0 { showCommandPalette = false; restoreSearchFocusIfNeeded() } }
                            ),
                            attachmentAnchor: .point(.top),
                            arrowEdge: .top
                        ) {
                            CommandPaletteContent(
                                item: item,
                                isMultiSelected: isMultiSelected,
                                onAction: { handleCommandAction($0) },
                                onDismiss: { showCommandPalette = false; restoreSearchFocusIfNeeded() }
                            )
                        }
                        .onTapGesture {
                            handleItemClick(itemID)
                        }
                        .contextMenu {
                            quickPanelItemContextMenu(for: item, itemID: itemID)
                        }
                        .onAppear {
                            if item.id == filteredItems.last?.id { store.loadMore() }
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.vertical, metrics.verticalPadding)
                .background(HorizontalWheelScrollAdapter())
            }
            .scrollClipDisabled()
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .top
            )
            .onChange(of: lastNavigatedID) {
                guard let id = lastNavigatedID else { return }
                withAnimation(.easeOut(duration: 0.16)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            .onChange(of: selectedFilter) {
                guard let firstID = cachedDisplayOrder.first?.persistentModelID else { return }
                withAnimation(.easeOut(duration: 0.16)) {
                    proxy.scrollTo(firstID, anchor: .leading)
                }
            }
        }
    }

    // MARK: - Empty State

    private var isFilterActive: Bool {
        selectedFilter != .all || !searchText.isEmpty || selectedGroupFilter != nil
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.quaternary)
            Text(L10n.tr("empty.noResults"))
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomEmptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.white.opacity(0.3))
            Text(L10n.tr("empty.noResults"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.56))
            if bottomMode == .compact {
                Text(L10n.tr("quick.expandHint"))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.36))
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewPane: some View {
        if isMultiSelected {
            multiSelectPreview
        } else if let item = currentItem {
            QuickPreviewPane(item: item, searchText: searchText, usesBottomFloatingStyle: isBottomFloatingStyle)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "square.text.square")
                    .font(.system(size: 24))
                    .foregroundStyle(.quaternary)
                Text(L10n.tr("empty.message"))
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var multiSelectPreview: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(isBottomFloatingStyle ? Color.white.opacity(0.38) : Color.secondary.opacity(0.6))
            Text(L10n.tr("quick.multiSelected", selectedItemIDs.count))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isBottomFloatingStyle ? Color.white.opacity(0.72) : Color.secondary)
            Text(L10n.tr("quick.batchPaste"))
                .font(.system(size: 12))
                .foregroundStyle(isBottomFloatingStyle ? Color.white.opacity(0.5) : Color.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footerBar: some View {
        VStack(spacing: 0) {
            // Expandable shortcuts panel
            if showAllShortcuts {
                HStack(spacing: 12) {
                    footerKey("←→", L10n.tr("quick.switchType"))
                    footerKey("↑↓", L10n.tr("quick.navigate"))
                    footerKey("⌘O", currentItem?.contentType == .link ? L10n.tr("quick.openLink") : L10n.tr("quick.preview"))
                    footerKey("⌘⌫", L10n.tr("quick.delete"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .background(Color.primary.opacity(0.02))
            }

            // Main footer bar
            HStack(spacing: 0) {
                if let prevApp = targetApp,
                   let appName = prevApp.localizedName {
                    HStack(spacing: 4) {
                        if let icon = prevApp.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 14, height: 14)
                        }
                        Text(L10n.tr("quick.pasteTo", appName))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("PasteMemo")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.quaternary)
                }
                Spacer()
                HStack(spacing: 12) {
                    if isMultiSelected {
                        if isTargetFinder {
                            footerKey("↵", L10n.tr("quick.saveToFolder"))
                        } else {
                            footerKey("↵", L10n.tr("quick.batchPaste"))
                            footerKey("⇧↵", L10n.tr("quick.pasteNewLine"))
                        }
                        footerKey("⌘↵", L10n.tr("action.pasteAsPlainText"))
                    } else {
                        if let cur = currentItem {
                            if cur.imageData != nil, canPasteToFinderFolder {
                                footerKey("↵", L10n.tr("quick.pasteImage"))
                            } else if canSaveTextToFolder {
                                footerKey("↵", L10n.tr("quick.saveToFolder"))
                            } else {
                                footerKey("↵", L10n.tr("quick.pasteAction"))
                                footerKey("⇧↵", L10n.tr("quick.pasteNewLine"))
                            }
                            if isFileBasedItem(cur) {
                                footerKey("⌘↵", L10n.tr("quick.pastePath"))
                            } else if cur.contentType == .text || cur.contentType == .code {
                                footerKey("⌘↵", L10n.tr("action.pasteAsPlainText"))
                            }
                        }
                    }
                    if let cur = currentItem, cur.isSensitive, !isMultiSelected {
                        footerKey("⌥", L10n.tr("sensitive.peek"))
                    }
                    footerKey("⌘K", L10n.tr("cmd.title"))
                    footerKey("esc", L10n.tr("quick.close"))

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showAllShortcuts.toggle()
                        }
                    } label: {
                        Image(systemName: showAllShortcuts ? "keyboard.chevron.compact.down" : "keyboard")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.03))
        }
    }

    private var compactFooterBar: some View {
        HStack(spacing: 12) {
            footerKey("Space", L10n.tr("quick.preview"))
            footerKey("←→", L10n.tr("quick.navigate"))
            footerKey("↑↓", L10n.tr("quick.switchType"))
            footerKey("⌘O", bottomMode == .compact ? L10n.tr("quick.expandDetails") : L10n.tr("quick.collapseDetails"))
            footerKey("↵", L10n.tr("quick.pasteAction"))
            footerKey("⌘K", L10n.tr("cmd.title"))
            footerKey("esc", L10n.tr("quick.collapseDetails"))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    private func footerKey(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func quickPanelItemContextMenu(for item: ClipItem, itemID: PersistentIdentifier) -> some View {
        if isMultiSelected, selectedItemIDs.contains(itemID) {
            multiSelectionContextMenu(items: currentItems)
        } else {
            singleItemContextMenu(item: item, itemID: itemID)
        }
    }

    @ViewBuilder
    private func multiSelectionContextMenu(items: [ClipItem]) -> some View {
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
    private func singleItemContextMenu(item: ClipItem, itemID: PersistentIdentifier) -> some View {
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

        Button(L10n.tr("action.mergeCopy")) {
            copyItemsToClipboard([item])
            selectItem(itemID)
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

    // MARK: - Actions

    private func moveSelection(_ delta: Int, extendSelection: Bool = false) {
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

    private func setBottomMode(_ newMode: QuickPanelBottomMode, animated: Bool = true) {
        guard isBottomFloatingStyle else { return }
        if newMode == .expanded {
            keepBottomDetailsMounted = true
        }
        bottomMode = newMode
        QuickPanelWindowController.shared.setBottomFloatingMode(newMode, animated: animated)
    }

    private func toggleBottomMode() {
        setBottomMode(bottomMode == .compact ? .expanded : .compact)
    }

    private func prewarmBottomDetailsIfNeeded() {
        guard isBottomFloatingStyle, !filteredItems.isEmpty, !keepBottomDetailsMounted else { return }
        DispatchQueue.main.async {
            keepBottomDetailsMounted = true
        }
    }

    private func installKeyMonitor() {
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
                case 126: moveSelection(-1, extendSelection: hasShift); return nil
            case 125: moveSelection(1, extendSelection: hasShift); return nil
            case 123: switchType(-1); return nil
            case 124: switchType(1); return nil
            case 48: switchType(hasShift ? -1 : 1); return nil  // Tab / Shift+Tab
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
    private static let digitKeyMap: [Int: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5,
        22: 6, 26: 7, 28: 8, 25: 9,
    ]

    private var availableContentTypes: [ClipContentType] { store.availableTypes }

    private func switchType(_ delta: Int) {
        let types = availableContentTypes
        let allFilters: [QuickFilter] = [.pinned, .all] + types.map { .type($0) }

        if let idx = allFilters.firstIndex(of: selectedFilter) {
            let newIdx = (idx + delta + allFilters.count) % allFilters.count
            selectedFilter = allFilters[newIdx]
        } else {
            selectedFilter = delta > 0 ? allFilters.first! : allFilters.last!
        }
    }

    private func handleCommandAction(_ action: CommandAction) {
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

    private func removeKeyMonitor() {
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor); keyMonitor = nil }
        if let monitor = flagsMonitor { NSEvent.removeMonitor(monitor); flagsMonitor = nil }
        OptionKeyMonitor.shared.isOptionPressed = false
    }

    /// Returns 1-based shortcut index (1~9) for the item, or nil if beyond top 9.
    private func shortcutIndex(for item: ClipItem) -> Int? {
        guard let first9 = cachedDisplayOrder.prefix(9).firstIndex(where: { $0.persistentModelID == item.persistentModelID }) else { return nil }
        return first9 + 1
    }

    private func handleShortcutPaste(index: Int) {
        let items = displayOrderItems
        guard index >= 1, index <= 9, index <= items.count else { return }
        let target = items[index - 1]
        selectItem(target.persistentModelID)
        handlePaste()
    }

    private func isFileBasedItem(_ item: ClipItem) -> Bool {
        item.contentType.isFileBased && !(item.contentType == .image && item.content == "[Image]")
    }

    private func isPureImage(_ item: ClipItem) -> Bool {
        item.contentType == .image && item.content == "[Image]" && item.imageData != nil
    }

    private var canPasteToFinderFolder: Bool {
        guard let item = currentItem, item.imageData != nil else { return false }
        return clipboardManager.isFinderApp(QuickPanelWindowController.shared.previousApp)
    }

    private func handleMultiPaste(asPlainText: Bool, forceNewLine: Bool = false) {
        let items = currentItems
        guard !items.isEmpty else { return }

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

    private func handleMultiPasteToFinder(_ items: [ClipItem]) {
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

    private func dismissAndRestoreApp(action: @escaping (NSRunningApplication) -> Void) {
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

    private func copyItemsToClipboard(_ items: [ClipItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let merged = items.map(\.content).joined(separator: "\n")
        pasteboard.setString(merged, forType: .string)
        clipboardManager.lastChangeCount = pasteboard.changeCount
        showCopiedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showCopiedToast = false }
    }

    private func handleDeleteSelected() {
        let itemsToDelete = isMultiSelected ? currentItems : (currentItem.map { [$0] } ?? [])
        deleteItems(itemsToDelete)
    }

    private func copyDebugInfo(for item: ClipItem) {
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

    private func deleteItem(_ item: ClipItem) {
        deleteItems([item])
    }

    private func assignToGroup(items: [ClipItem], name: String) {
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

    private func removeFromGroup(items: [ClipItem]) {
        for item in items {
            guard let name = item.groupName, !name.isEmpty else { continue }
            item.groupName = nil
            ClipboardManager.shared.decrementSmartGroup(name: name, context: modelContext)
        }
        try? modelContext.save()
        store.refreshSidebarCounts()
    }

    @discardableResult
    private func showNewGroupAlert(for items: [ClipItem]) -> String? {
        guard let result = GroupEditorPanel.show() else { return nil }
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

    private func applyTransform(_ action: RuleAction, to item: ClipItem) {
        let processed = AutomationEngine.shared.applyAction(action, to: item.content)
        item.content = processed
        item.displayTitle = ClipItem.buildTitle(content: processed, contentType: item.contentType)
        if action == .stripRichText {
            item.richTextData = nil
            item.richTextType = nil
        }
        ClipItemStore.saveAndNotify(modelContext)
    }

    private func fetchEnabledRules() -> [AutomationRule] {
        let descriptor = FetchDescriptor<AutomationRule>(
            predicate: #Predicate { $0.enabled },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func applyRule(_ rule: AutomationRule, to item: ClipItem) {
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

    private func deleteItems(_ itemsToDelete: [ClipItem]) {
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

    private func guideRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).frame(width: 14)
            Text(text)
        }
    }

    private func emptyHintKey(_ key: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)
            Spacer()
        }
    }

    private func handleOpenLink() {
        guard let item = currentItem else { return }
        if item.contentType == .link,
           let url = URL(string: item.content.trimmingCharacters(in: .whitespacesAndNewlines)) {
            NSWorkspace.shared.open(url)
            handleDismiss()
        } else {
            QuickLookHelper.shared.toggle(item: item)
        }
    }

    private func handleDismiss() { HotkeyManager.shared.hideQuickPanel() }

    private func togglePreview() {
        if QuickLookHelper.shared.isVisible {
            QuickLookHelper.shared.closePreview()
            return
        }
        guard !isMultiSelected, let item = currentItem else { return }
        QuickLookHelper.shared.toggle(item: item)
    }

    private var isTargetFinder: Bool {
        clipboardManager.isFinderApp(QuickPanelWindowController.shared.previousApp)
    }

    private var canSaveAttachmentToFolder: Bool {
        guard let item = currentItem,
              item.imageData != nil,
              item.contentType != .image else { return false }
        return isTargetFinder
    }

    private var canSaveTextToFolder: Bool {
        guard let item = currentItem,
              item.contentType == .text || item.contentType == .code,
              item.imageData == nil else { return false }
        return isTargetFinder
    }

    private func handleCmdEnter() {
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

    private func handlePlainTextPaste(_ item: ClipItem) {
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

    private func handlePasteTextToFolder() {
        guard let item = currentItem else { return }

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

    private func handlePasteImage() {
        guard let item = currentItem, let imageData = item.imageData else { return }
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

    private func handlePastePath() {
        guard let item = currentItem, isFileBasedItem(item) else { return }
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

    private func handlePaste(forceNewLine: Bool = false) {
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

    private func handlePasteImageToFolder() {
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

struct KeyCap: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
    }
}
