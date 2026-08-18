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

    @Environment(\.colorScheme) private var colorScheme

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
    }

    private var palette: QuickPanelBottomTheme.Palette {
        .resolve(colorScheme)
    }

    private var accent: Color {
        PasteCardAccent.resolved(type: item.contentType, bundleID: item.sourceAppBundleID).color
    }

    private var regularBody: some View {
        VStack(spacing: 0) {
            header
            preview
        }
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: QuickPanelBottomTheme.cardCornerRadius, style: .continuous))
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
                .fill(palette.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: QuickPanelBottomTheme.cardCornerRadius, style: .continuous)
                .stroke(accent.opacity(isSelected ? 1 : 0.45), lineWidth: isSelected ? 2 : 1)
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
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                if !footerTitle.isEmpty {
                    Text(footerTitle)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(palette.footerTitle)
                        .lineLimit(1)
                }
                Text(metaText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.footerMeta)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let shortcutIndex {
                Text("⌘\(shortcutIndex)")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.shortcutText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(palette.shortcutFill)
                    )
                    .opacity(isLiveResizing ? 0.75 : 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: palette.footerScrim,
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: QuickPanelBottomTheme.cardCornerRadius, style: .continuous)
            .fill(palette.cardFill)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: QuickPanelBottomTheme.cardCornerRadius, style: .continuous)
            .strokeBorder(
                accent.opacity(isSelected ? 1 : 0.55),
                lineWidth: isSelected ? 2.2 : 1.2
            )
    }

    private var headerBackground: some View {
        LinearGradient(
            colors: [accent, accent.opacity(0.88)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var sourceAppIcon: NSImage? {
        appIcon(forBundleID: item.sourceAppBundleID, name: item.sourceApp)
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
        LinearGradient(
            colors: [palette.previewTop, palette.previewBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
                    .foregroundStyle(palette.primaryText)
                Text(L10n.tr("sensitive.optionHint"))
                    .font(.system(size: 11))
                    .foregroundStyle(palette.secondaryText)
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
                            .foregroundStyle(palette.secondaryText)
                            .frame(width: 24, height: 24)
                            .background(palette.shortcutFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    Text(linkHost)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }

                if searchText.isEmpty {
                    Text(linkTitle)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                } else {
                    HighlightedText(linkTitle, query: extractSearchQuery(from: searchText))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Text(item.content)
                    .font(.system(size: 10.5))
                    .foregroundStyle(palette.tertiaryText)
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
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(3)
                } else {
                    HighlightedText(fileDisplayTitle, query: extractSearchQuery(from: searchText))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(3)
                }

                Spacer(minLength: 0)

                if let sourceApp = item.sourceApp, !sourceApp.isEmpty {
                    Text(sourceApp)
                        .font(.system(size: 10.5))
                        .foregroundStyle(palette.tertiaryText)
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
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if searchText.isEmpty {
                    Text(primaryText)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(4)
                } else {
                    HighlightedText(primaryText, query: extractSearchQuery(from: searchText))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(4)
                }

                Text(secondaryText)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.secondaryText)
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
                .foregroundStyle(palette.secondaryText)

            Text(primaryText)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(palette.primaryText)
                .lineLimit(3)

            Spacer(minLength: 0)

            Text(lightweightMetaText)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(palette.tertiaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var footerTitle: String {
        switch item.contentType {
        case .link:
            return linkTitle
        case .file, .document, .archive, .application, .video, .audio:
            return fileDisplayTitle
        case .image, .color:
            return ""
        default:
            return ""
        }
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
