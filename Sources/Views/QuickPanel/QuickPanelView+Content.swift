import SwiftUI
import SwiftData
import AppKit

extension QuickPanelView {
    var classicLayout: some View {
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

    var bottomFloatingLayout: some View {
        GeometryReader { proxy in
            let metrics = resolvedBottomCardLayoutMetrics(for: proxy.size)

            VStack(spacing: 8) {
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
            .padding(.top, 4)
            .padding(.bottom, 2)
        }
        .transaction { transaction in
            if isLiveResizing {
                transaction.animation = nil
            }
        }
        .frame(
            minWidth: QuickPanelBottomGeometry.minimumWidth,
            idealWidth: QuickPanelBottomGeometry.minimumWidth,
            maxWidth: .infinity,
            minHeight: bottomMode == .compact ? QuickPanelBottomGeometry.compactHeight : QuickPanelBottomGeometry.expandedHeight,
            maxHeight: .infinity
        )
    }

    func quantizedLiveResizeLength(_ value: CGFloat, step: CGFloat) -> CGFloat {
        let scaled = (value / step).rounded()
        return max(step, scaled * step)
    }

    var bottomDetailsSection: some View {
        VStack(spacing: 8) {
            Group {
                if isLiveResizing {
                    bottomDetailsPlaceholder
                } else {
                    previewPane
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            compactFooterBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .quickPanelBottomSection()
    }

    // MARK: - List

    var clipList: some View {
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
                                    .overlay(
                                        RightClickSelector {
                                            if !selectedItemIDs.contains(itemID) {
                                                selectItem(itemID, allowsDirectionalFallback: false)
                                            }
                                        }
                                    )
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
                .onChange(of: scrollRequestToken) {
                guard let id = pendingScrollRequestID else { return }
                withAnimation(.easeOut(duration: 0.16)) {
                    proxy.scrollTo(id, anchor: .top)
                }
                pendingScrollRequestID = nil
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

    func bottomClipRail(metrics: BottomCardLayoutMetrics) -> some View {
        Group {
            if isLiveResizing {
                bottomLiveResizeClipRail(metrics: metrics)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: metrics.spacing) {
                            ForEach(displayOrderItems) { item in
                                let itemID = item.persistentModelID
                                QuickClipCard(
                                    item: item,
                                    isSelected: selectedItemIDs.contains(itemID),
                                    isLiveResizing: false,
                                    shortcutIndex: shortcutIndex(for: item),
                                    cardWidth: metrics.cardWidth,
                                    cardHeight: metrics.cardHeight,
                                    searchText: searchText
                                )
                                .background(
                                    BottomClipEnsureVisibleProbe(
                                        itemID: itemID,
                                        activeID: lastNavigatedID,
                                        edgePadding: 8,
                                        animationDuration: 0.16
                                    )
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
                                .overlay(
                                    RightClickSelector {
                                        if !selectedItemIDs.contains(itemID) {
                                            selectItem(itemID, allowsDirectionalFallback: false)
                                        }
                                    }
                                )
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
                    .onChange(of: lastNavigatedID) { previousID, currentID in
                        guard let id = currentID else { return }
                        ensureBottomClipVisible(id: id, previousID: previousID, proxy: proxy)
                    }
                    .onChange(of: scrollRequestToken) {
                        guard let id = pendingScrollRequestID else { return }
                        withAnimation(.easeOut(duration: 0.16)) {
                            proxy.scrollTo(id, anchor: .leading)
                        }
                        pendingScrollRequestID = nil
                    }
                    .onChange(of: selectedFilter) {
                        guard let firstID = cachedDisplayOrder.first?.persistentModelID else { return }
                        withAnimation(.easeOut(duration: 0.16)) {
                            proxy.scrollTo(firstID, anchor: .leading)
                        }
                    }
                }
            }
        }
    }

    func bottomLiveResizeClipRail(metrics: BottomCardLayoutMetrics) -> some View {
        LiveResizeRailRepresentable(
            cards: liveResizeDisplayOrderItems.map { item in
                LiveResizeCardSnapshot(
                    id: item.itemID,
                    isSelected: selectedItemIDs.contains(item.persistentModelID)
                )
            },
            metrics: metrics
        )
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .top
        )
    }

    var liveResizeDisplayOrderItems: [ClipItem] {
        let maxVisibleItems = 10
        let focusID = lastNavigatedID ?? selectedItemIDs.first ?? defaultItem?.persistentModelID
        let bounds = QuickPanelSelectionLogic.visibleSliceBounds(
            itemIDs: displayOrderItems.map(\.persistentModelID),
            focusedID: focusID,
            maxVisibleItems: maxVisibleItems
        )
        return Array(displayOrderItems[bounds])
    }

    // MARK: - Empty State

    var isFilterActive: Bool {
        selectedFilter != .all || !searchText.isEmpty || selectedGroupFilter != nil
    }

    var emptyStateView: some View {
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

    var bottomEmptyState: some View {
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
    var previewPane: some View {
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

    var multiSelectPreview: some View {
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

    var bottomDetailsPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 36, height: 36)
                    .background(
                        QuickPanelBottomTheme.controlFill,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("正在调整悬浮框大小")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))

                    Text("详情预览已暂时降级，松开鼠标后会立即恢复。")
                        .font(.system(size: 12))
                        .foregroundStyle(QuickPanelBottomTheme.secondaryText)
                }

                Spacer(minLength: 0)
            }

            RoundedRectangle(cornerRadius: QuickPanelBottomTheme.previewCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: QuickPanelBottomTheme.previewCornerRadius, style: .continuous)
                        .stroke(QuickPanelBottomTheme.thinStroke, lineWidth: 1)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "rectangle.3.group")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                        Text("预览恢复中")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(QuickPanelBottomTheme.tertiaryText)
                    }
                }
        }
        .padding(12)
    }

    // MARK: - Footer

    var footerBar: some View {
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
                            footerKey("⌘↵", L10n.tr("quick.pasteNewLine"))
                        }
                        footerKey("⇧↵", L10n.tr("action.pasteAsPlainText"))
                    } else {
                        if let cur = currentItem {
                            if cur.imageData != nil, canPasteToFinderFolder {
                                footerKey("↵", L10n.tr("quick.pasteImage"))
                            } else if canSaveTextToFolder {
                                footerKey("↵", L10n.tr("quick.saveToFolder"))
                            } else {
                                footerKey("↵", L10n.tr("quick.pasteAction"))
                                footerKey("⌘↵", L10n.tr("quick.pasteNewLine"))
                            }
                            if isFileBasedItem(cur) {
                                footerKey("⇧↵", L10n.tr("quick.pastePath"))
                            } else if [.text, .code, .color, .email, .phone].contains(cur.contentType) {
                                footerKey("⇧↵", L10n.tr("action.pasteAsPlainText"))
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

    var compactFooterBar: some View {
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

    func footerKey(_ key: String, _ label: String) -> some View {
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


    func guideRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).frame(width: 14)
            Text(text)
        }
    }

    func emptyHintKey(_ key: String, _ label: String) -> some View {
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
}
