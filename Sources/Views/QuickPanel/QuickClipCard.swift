import SwiftUI
import AppKit

struct QuickClipCard: View {
    let item: ClipItem
    let isSelected: Bool
    let isLiveResizing: Bool
    let shortcutIndex: Int?
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    var searchText: String = ""
    
    @State private var isHovered: Bool = false

    init(
        item: ClipItem,
        isSelected: Bool,
        isLiveResizing: Bool = false,
        shortcutIndex: Int?,
        cardWidth: CGFloat = 188,
        cardHeight: CGFloat = 220,
        searchText: String = ""
    ) {
        self.item = item
        self.isSelected = isSelected
        self.isLiveResizing = isLiveResizing
        self.shortcutIndex = shortcutIndex
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
        self.searchText = searchText
    }

    var body: some View {
        Group {
            if isLiveResizing {
                liveResizeBody
            } else {
                regularBody
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .contentShape(RoundedRectangle(cornerRadius: QuickPanelBottomTheme.cardCornerRadius, style: .continuous))
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }

    private var regularBody: some View {
        VStack(spacing: 0) {
            header
            preview
        }
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: QuickPanelBottomTheme.cardCornerRadius, style: .continuous))
        .shadow(
            color: isSelected ? QuickPanelBottomTheme.selectionBlue.opacity(0.22) : .black.opacity(0.20),
            radius: isSelected ? 18 : 10,
            y: isSelected ? 8 : 5
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .offset(y: isSelected ? -1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }

    private var liveResizeBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: item.contentType.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white.opacity(isSelected ? 0.92 : 0.76))
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(isSelected ? 0.16 : 0.08))
                    )

                Spacer(minLength: 0)

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 34, height: 10)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Spacer(minLength: 12)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: min(cardWidth * 0.58, 104), height: 10)

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .frame(maxWidth: .infinity)
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: max(cardWidth * 0.46, 58), height: 8)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: QuickPanelBottomTheme.cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isSelected
                            ? [
                                QuickPanelBottomTheme.accentBlue.opacity(0.44),
                                Color(red: 0.11, green: 0.13, blue: 0.18),
                            ]
                            : [
                                Color(red: 0.10, green: 0.10, blue: 0.11),
                                Color(red: 0.09, green: 0.09, blue: 0.10),
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: QuickPanelBottomTheme.cardCornerRadius, style: .continuous)
                .stroke(isSelected ? QuickPanelBottomTheme.selectionBlue.opacity(0.44) : Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private var header: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.contentType.label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if item.isPinned {
                        HStack(spacing: 4) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(L10n.tr("time.pinned"))
                                .font(.system(size: 9.5, weight: .bold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.16))
                        )
                    }

                    Text(formatTimeAgo(item.lastUsedAt))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
                .frame(maxHeight: .infinity, alignment: .center)

                Spacer(minLength: 0)
            }
            .padding(.leading, 14)
            .padding(.trailing, headerBadgeWidth + 2)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            headerIconPanel
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background(headerBackground)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: QuickPanelBottomTheme.cardCornerRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: QuickPanelBottomTheme.cardCornerRadius
            )
        )
    }

    private var preview: some View {
        ZStack(alignment: .bottomLeading) {
            previewBackground
            previewContent
                .padding(previewContentPadding)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(metaText)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(1)

            Spacer(minLength: 0)

            if let shortcutIndex {
                Text("⌘\(shortcutIndex)")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .opacity(isLiveResizing ? 0.75 : 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Group {
                if isLiveResizing {
                    Color.black.opacity(0.16)
                } else {
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.10), Color.black.opacity(0.24)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: QuickPanelBottomTheme.cardCornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: isLiveResizing
                        ? [
                            Color(red: 0.11, green: 0.11, blue: 0.12),
                            Color(red: 0.10, green: 0.10, blue: 0.11),
                        ]
                        : isSelected
                        ? [
                            Color(red: 0.12, green: 0.24, blue: 0.46),
                            Color(red: 0.09, green: 0.18, blue: 0.35),
                        ]
                        : [
                            Color(red: 0.12, green: 0.12, blue: 0.13),
                            Color(red: 0.09, green: 0.09, blue: 0.10),
                        ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: QuickPanelBottomTheme.cardCornerRadius, style: .continuous)
            .strokeBorder(
                isLiveResizing
                    ? AnyShapeStyle(Color.white.opacity(0.06))
                    : isSelected
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                QuickPanelBottomTheme.accentBlue,
                                QuickPanelBottomTheme.selectionBlue,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    : AnyShapeStyle(
                        Color.white.opacity(0.08)
                    ),
                lineWidth: isSelected && !isLiveResizing ? 1.6 : 1
            )
    }

    private var headerBackground: some View {
        LinearGradient(
            colors: isLiveResizing
                ? [
                    Color.white.opacity(0.16),
                    Color.white.opacity(0.08),
                ]
                : isSelected
                ? [
                    QuickPanelBottomTheme.accentBlue.opacity(0.96),
                    QuickPanelBottomTheme.selectionBlue.opacity(0.88),
                ]
                : headerGradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var headerGradientColors: [Color] {
        CardColorCache.shared.getGradientColors(for: item, icon: sourceAppIcon)
    }

    private var sourceAppIcon: NSImage? {
        appIcon(forBundleID: item.sourceAppBundleID, name: item.sourceApp)
    }
    
    @MainActor
    private var sampledHeaderBaseColor: NSColor? {
        CardColorCache.shared.getHeaderBaseColor(for: item, icon: sourceAppIcon)
    }

    private var previewContentPadding: EdgeInsets {
        switch item.contentType {
        case .image:
            return EdgeInsets()
        default:
            return EdgeInsets(top: 14, leading: 14, bottom: 42, trailing: 14)
        }
    }

    private var headerBadgeWidth: CGFloat {
        min(max(cardWidth * 0.20, 64), 78)
    }

    private var headerIconPanel: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 0,
                topTrailingRadius: QuickPanelBottomTheme.cardCornerRadius
            )
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.18), Color.white.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 24,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: QuickPanelBottomTheme.cardCornerRadius
                )
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            headerIconBadge
                .offset(x: -8, y: 0)
        }
        .frame(width: headerBadgeWidth, height: 56)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 0,
                topTrailingRadius: QuickPanelBottomTheme.cardCornerRadius
            )
        )
    }

    @ViewBuilder
    private var headerIconBadge: some View {
        if isLiveResizing {
            Image(systemName: item.contentType.icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white.opacity(0.82))
        } else if let sourceAppIcon {
            Image(nsImage: sourceAppIcon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: min(headerBadgeWidth - 18, 32), height: 32)
                .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
        } else {
            Image(systemName: item.contentType.icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
        }
    }

    @ViewBuilder
    private var previewBackground: some View {
        QuickPanelBottomTheme.previewBackground
    }

    @ViewBuilder
    private var previewContent: some View {
        if item.isSensitive {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)
                Text(L10n.tr("sensitive.masked"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Text(L10n.tr("sensitive.optionHint"))
                    .font(.system(size: 11))
                    .foregroundStyle(QuickPanelBottomTheme.secondaryText)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if isLiveResizing {
            resizingPlaceholder
        } else if item.contentType == .image,
                  let data = item.imageData,
                  let image = ImageCache.shared.thumbnail(for: data, key: item.itemID, size: imagePreviewMaxDimension) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if item.contentType == .link {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    if let data = item.faviconData,
                       let image = ImageCache.shared.favicon(for: data, key: item.content) {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 24, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    } else {
                        Image(systemName: "link")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    Text(linkHost)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }

                if searchText.isEmpty {
                    Text(linkTitle)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                } else {
                    HighlightedText(linkTitle, query: extractSearchQuery(from: searchText))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Text(item.content)
                    .font(.system(size: 10.5))
                    .foregroundStyle(QuickPanelBottomTheme.tertiaryText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if item.contentType.isFileBased, let firstPath {
            VStack(alignment: .leading, spacing: 10) {
                Image(nsImage: systemIcon(forFile: firstPath))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)

                if searchText.isEmpty {
                    Text(fileDisplayTitle)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(3)
                } else {
                    HighlightedText(fileDisplayTitle, query: extractSearchQuery(from: searchText))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(3)
                }

                Spacer(minLength: 0)

                if let sourceApp = item.sourceApp, !sourceApp.isEmpty {
                    Text(sourceApp)
                        .font(.system(size: 10.5))
                        .foregroundStyle(QuickPanelBottomTheme.tertiaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if item.contentType == .color, let parsed = ColorConverter.parse(item.content) {
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: parsed.nsColor))
                    .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                Text(parsed.formatted(parsed.originalFormat))
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if searchText.isEmpty {
                    Text(primaryText)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                        .lineLimit(4)
                } else {
                    HighlightedText(primaryText, query: extractSearchQuery(from: searchText))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                        .lineLimit(4)
                }

                Text(secondaryText)
                    .font(.system(size: 11))
                    .foregroundStyle(QuickPanelBottomTheme.secondaryText)
                    .lineLimit(6)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var imagePreviewMaxDimension: CGFloat {
        let headerHeight: CGFloat = 56
        let footerHeight: CGFloat = 42
        let previewPadding: CGFloat = 8

        let availableWidth = max(cardWidth - previewPadding, 72)
        let availableHeight = max(cardHeight - headerHeight - footerHeight - previewPadding, 72)

        return max(min(availableWidth, availableHeight), 72)
    }

    private var resizingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: item.contentType == .image ? "photo" : item.contentType.icon)
                .font(.system(size: item.contentType == .image ? 26 : 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.76))

            Text(primaryText)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(3)

            Spacer(minLength: 0)

            Text(lightweightMetaText)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(QuickPanelBottomTheme.tertiaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var primaryText: String {
        let title = item.displayTitle ?? item.content
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var secondaryText: String {
        let normalized = item.content
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return L10n.tr("empty.message") }
        if normalized == primaryText { return L10n.tr("help.action.paste") }
        return normalized
    }

    private var linkTitle: String {
        if let linkTitle = item.linkTitle, !linkTitle.isEmpty {
            return linkTitle
        }
        return item.displayTitle ?? item.content
    }

    private var linkHost: String {
        URL(string: item.content)?.host ?? item.sourceApp ?? "Link"
    }

    private var fileDisplayTitle: String {
        let paths = item.content
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let first = paths.first else { return item.displayTitle ?? item.content }
        if paths.count == 1 {
            return URL(fileURLWithPath: first).lastPathComponent
        }
        return "\(URL(fileURLWithPath: first).lastPathComponent) +\(paths.count - 1)"
    }

    private var metaText: String {
        switch item.contentType {
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                return "\(Int(image.size.width)) × \(Int(image.size.height))"
            }
            return formatTimeAgo(item.lastUsedAt)
        case .file, .document, .archive, .application, .video, .audio:
            let count = item.content.split(separator: "\n").count
            return count > 1 ? "\(count) 个项目" : formatTimeAgo(item.lastUsedAt)
        case .link:
            return linkHost
        case .color:
            return "颜色样本"
        default:
            return "\(item.content.count) 字符"
        }
    }

    private var lightweightMetaText: String {
        switch item.contentType {
        case .image:
            return "图片"
        case .link:
            return linkHost
        case .file, .document, .archive, .application, .video, .audio:
            let count = item.content.split(separator: "\n").count
            return count > 1 ? "\(count) 个项目" : formatTimeAgo(item.lastUsedAt)
        case .color:
            return "颜色样本"
        default:
            return formatTimeAgo(item.lastUsedAt)
        }
    }

    private var firstPath: String? {
        item.content
            .split(separator: "\n")
            .first
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    private func extractSearchQuery(from searchText: String) -> String {
        // 移除正则搜索前缀
        if searchText.hasPrefix("regex:") {
            return String(searchText.dropFirst(6))
        }
        // 移除模糊搜索前缀
        if searchText.hasPrefix("fuzzy:") {
            return String(searchText.dropFirst(6))
        }
        return searchText
    }
}
