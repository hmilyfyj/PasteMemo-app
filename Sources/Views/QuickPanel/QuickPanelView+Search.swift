import SwiftUI
import SwiftData
import AppKit

extension QuickPanelView {
    // MARK: - Search

    static let GROUP_SEARCH_PREFIX = "/"

    enum SuggestionItem: Equatable {
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

    var isShowingSuggestions: Bool {
        QuickPanelSearchLogic.shouldShowSuggestions(
            selectedGroupFilter: selectedGroupFilter,
            searchText: searchText,
            groupCount: currentSuggestionGroups.count,
            appCount: currentSuggestionApps.count,
            prefix: Self.GROUP_SEARCH_PREFIX
        )
    }

    var currentSuggestionGroups: [QuickPanelGroupSuggestion] {
        guard let query = QuickPanelSearchLogic.suggestionQuery(
            for: searchText,
            prefix: Self.GROUP_SEARCH_PREFIX
        ) else { return [] }

        let groups = store.sidebarCounts.byGroup.map {
            QuickPanelGroupSuggestion(name: $0.name, icon: $0.icon, count: $0.count)
        }
        return QuickPanelSearchLogic.matchingGroupSuggestions(query: query, groups: groups)
    }

    var currentSuggestionApps: [QuickPanelAppSuggestion] {
        guard let query = QuickPanelSearchLogic.suggestionQuery(
            for: searchText,
            prefix: Self.GROUP_SEARCH_PREFIX
        ) else { return [] }

        return QuickPanelSearchLogic.matchingAppSuggestions(
            query: query,
            apps: store.sourceApps,
            counts: Dictionary(
                uniqueKeysWithValues: store.sidebarCounts.byApp.compactMap { key, value in
                    guard let key else { return nil }
                    return (key, value)
                }
            )
        )
    }

    var totalSuggestionCount: Int {
        currentSuggestionGroups.count + currentSuggestionApps.count
    }

    @ViewBuilder
    var groupSuggestions: some View {
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

    func suggestionSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }

    func suggestionRow(icon: String, appName: String? = nil, name: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
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

    func selectSuggestion(_ item: SuggestionItem) {
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

    func clearGroupFilter() {
        selectedGroupFilter = nil
        store.groupName = nil
        store.sourceApp = nil
        store.applyFilters()
    }

    func applyCustomGroupFilter(_ name: String?) {
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

    var searchBar: some View {
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

    var bottomHeader: some View {
        Group {
            if isLiveResizing {
                bottomHeaderLiveResize
            } else {
                ViewThatFits(in: .horizontal) {
                    bottomHeaderSingleRow
                    bottomHeaderCompactSingleRow
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 1)
        .background(QuickPanelWindowDragArea())
    }

    var bottomHeaderLiveResize: some View {
        HStack(spacing: 10) {
            bottomHeaderLiveResizeSummary
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                bottomHeaderLiveResizeModeBadge
                bottomPinButton
                bottomCountBadge
                bottomOverflowMenuButton
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    var bottomHeaderLiveResizeSummary: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))

            Text(bottomHeaderLiveResizeText)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(QuickPanelBottomTheme.mutedFill, in: Capsule())
    }

    var bottomHeaderLiveResizeModeBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: bottomMode == .compact ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                .font(.system(size: 11, weight: .semibold))
            Text(bottomMode == .compact ? L10n.tr("quick.compactMode") : L10n.tr("quick.expandDetails"))
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.72))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(QuickPanelBottomTheme.mutedFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    var bottomHeaderLiveResizeText: String {
        if let filterName = selectedGroupFilter, !filterName.isEmpty {
            return filterName
        }
        if !searchText.isEmpty {
            return searchText
        }
        if let app = targetApp?.localizedName, !app.isEmpty {
            return L10n.tr("quick.pasteToApp", app)
        }
        return L10n.tr("filter.all")
    }

    var bottomHeaderSingleRow: some View {
        HStack(spacing: 10) {
            bottomInlineFilterBar
                .frame(minWidth: 280, idealWidth: 360, maxWidth: 460, alignment: .leading)

            Spacer(minLength: 0)

            bottomHeaderCenterCluster
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 0)

            bottomHeaderTrailingControls
        }
    }

    var bottomHeaderCompactSingleRow: some View {
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
                .frame(minWidth: 140, idealWidth: 220, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            bottomModeToggleIconButton
            bottomRelayButton
            bottomPinButton
            bottomCountBadge
            bottomOverflowMenuButton
        }
    }

    var bottomHeaderTrailingControls: some View {
        HStack(spacing: 8) {
            bottomTargetAppBadge
            bottomModeToggleButton
            bottomRelayButton
            bottomPinButton
            bottomCountBadge
            bottomOverflowMenuButton
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    var bottomHeaderCenterCluster: some View {
        HStack(spacing: 10) {
            bottomSearchField
                .frame(
                    minWidth: bottomSearchFieldWidth,
                    idealWidth: bottomSearchFieldWidth,
                    maxWidth: bottomSearchFieldWidth,
                    alignment: .center
                )

            bottomCustomGroupToolbar
        }
    }

    var bottomSearchField: some View {
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

    var tabBar: some View {
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

    var bottomInlineFilterBar: some View {
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

    var bottomCustomGroupToolbar: some View {
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
                        isSelected: currentCustomGroupFilterName == group.name,
                        groupName: group.name,
                        action: {
                            applyCustomGroupFilter(group.name)
                            restoreSearchFocusIfNeeded()
                        }
                    )
                }

                Button {
                    showNewGroupPanelFromToolbar()
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
        .frame(minWidth: 220, maxWidth: 600, minHeight: 28, maxHeight: 28)
    }

    func showNewGroupPanelFromToolbar() {
        isSearchFocused = false
        removeKeyMonitor()
        QuickPanelWindowController.shared.suppressDismiss = true

        DispatchQueue.main.async {
            GroupEditorPanel.showAsync() { result in
                QuickPanelWindowController.shared.suppressDismiss = false
                installKeyMonitor()

                guard let result else {
                    restoreSearchFocusIfNeeded()
                    return
                }

                let context = PasteMemoApp.sharedModelContainer.mainContext
                AppMenuActions.upsertGroup(name: result.name, icon: result.icon, context: context)
                try? context.save()
                AppMenuActions.notifyGroupStoreDidChange()
                store.refreshSidebarCounts()
                applyCustomGroupFilter(result.name)
                restoreSearchFocusIfNeeded()
            }
        }
    }

    func bottomGroupToolbarChip(
        title: String,
        systemImage: String,
        tint: Color,
        isSelected: Bool,
        groupName: String? = nil,
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
        .contextMenu {
            if let groupName = groupName {
                Button {
                    editGroupInQuickPanel(name: groupName)
                } label: {
                    Label(L10n.tr("action.editGroup"), systemImage: "pencil")
                }
                
                Button {
                    changeGroupIconInQuickPanel(name: groupName)
                } label: {
                    Label(L10n.tr("action.changeIcon"), systemImage: "paintbrush")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    confirmDeleteGroup(name: groupName)
                } label: {
                    Label(L10n.tr("action.deleteGroup"), systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    var bottomTargetAppBadge: some View {
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

    var bottomModeToggleButton: some View {
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

    var bottomModeToggleIconButton: some View {
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

    var bottomOverflowMenuButton: some View {
        Button {
            showBottomOverflowMenu.toggle()
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.86))
                .frame(width: 30, height: 24)
                .background(
                    showBottomOverflowMenu ? QuickPanelBottomTheme.controlFill.opacity(1.15) : QuickPanelBottomTheme.mutedFill,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(showBottomOverflowMenu ? 0.16 : 0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    var bottomPinButton: some View {
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

    var bottomRelayButton: some View {
        Button {
            handleRelayAction()
        } label: {
            Image(systemName: RelayManager.shared.isActive ? "arrowshape.turn.up.right.fill" : "arrowshape.turn.up.right")
                .font(.system(size: 11))
                .foregroundStyle(RelayManager.shared.isActive ? .white : .white.opacity(0.72))
                .frame(width: 24, height: 24)
                .background(
                    RelayManager.shared.isActive ? QuickPanelBottomTheme.accentBlue : QuickPanelBottomTheme.mutedFill,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .help(RelayManager.shared.isActive ? L10n.tr("relay.active") : L10n.tr("relay.addToQueue"))
    }

    var bottomCountBadge: some View {
        Text("\(store.totalCount)")
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .foregroundStyle(.white.opacity(0.72))
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(QuickPanelBottomTheme.mutedFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    func badge(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
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

    func bottomFilterBadge(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
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
}
