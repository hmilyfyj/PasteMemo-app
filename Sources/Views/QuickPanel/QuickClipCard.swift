import SwiftUI

struct QuickClipCard: View {
    let item: ClipItem
    let isSelected: Bool
    let shortcutIndex: Int?
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    init(
        item: ClipItem,
        isSelected: Bool,
        shortcutIndex: Int?,
        cardWidth: CGFloat = 188,
        cardHeight: CGFloat = 220
    ) {
        self.item = item
        self.isSelected = isSelected
        self.shortcutIndex = shortcutIndex
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            preview
            footer
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(cardBackground)
        .shadow(
            color: isSelected ? QuickPanelBottomTheme.selectionBlue.opacity(0.22) : .black.opacity(0.24),
            radius: isSelected ? 22 : 12,
            y: isSelected ? 12 : 6
        )
        .offset(y: isSelected ? -2 : 0)
        .contentShape(RoundedRectangle(cornerRadius: QuickPanelBottomTheme.cardCornerRadius, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.contentType.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(formatTimeAgo(item.lastUsedAt))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let icon = appIcon(forBundleID: item.sourceAppBundleID, name: item.sourceApp) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            } else {
                Image(systemName: item.contentType.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .frame(maxWidth: .infinity)
        .background(headerColor)
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
        ZStack {
            previewBackground
            previewContent
                .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(metaText)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(QuickPanelBottomTheme.tertiaryText)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let shortcutIndex {
                Text("⌘\(shortcutIndex)")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.66))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.07), in: Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: QuickPanelBottomTheme.cardCornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isSelected ? 0.12 : 0.06),
                        Color.white.opacity(isSelected ? 0.06 : 0.025),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    @MainActor
    private var headerColor: Color {
        QuickPanelBottomTheme.headerColor(for: item.contentType)
    }

    @ViewBuilder
    private var previewBackground: some View {
        if item.contentType == .image, item.imageData != nil {
            QuickPanelBottomCheckerboard(cornerRadius: 0)
        } else {
            LinearGradient(
                colors: [
                    Color.white.opacity(isSelected ? 0.08 : 0.05),
                    Color.black.opacity(0.08),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
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
        } else if item.contentType == .image,
                  let data = item.imageData,
                  let image = ImageCache.shared.preview(for: data, key: item.itemID, maxDimension: imagePreviewMaxDimension) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

                Text(linkTitle)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)

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

                Text(fileDisplayTitle)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(3)

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
                Text(primaryText)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(4)

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
        let headerHeight: CGFloat = 34
        let footerHeight: CGFloat = 38
        let previewPadding: CGFloat = 24

        let availableWidth = max(cardWidth - previewPadding, 72)
        let availableHeight = max(cardHeight - headerHeight - footerHeight - previewPadding, 72)

        return max(min(availableWidth, availableHeight), 72)
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

    private var firstPath: String? {
        item.content
            .split(separator: "\n")
            .first
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
