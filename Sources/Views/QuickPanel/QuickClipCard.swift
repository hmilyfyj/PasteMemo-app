import SwiftUI
import AppKit

@MainActor private var quickClipCardHeaderColorCache: [String: NSColor] = [:]

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
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: QuickPanelBottomTheme.cardCornerRadius, style: .continuous))
        .shadow(
            color: isSelected ? QuickPanelBottomTheme.selectionBlue.opacity(0.22) : .black.opacity(0.20),
            radius: isSelected ? 18 : 10,
            y: isSelected ? 8 : 5
        )
        .offset(y: isSelected ? -1 : 0)
        .contentShape(RoundedRectangle(cornerRadius: QuickPanelBottomTheme.cardCornerRadius, style: .continuous))
    }

    private var header: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.contentType.label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

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
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.10), Color.black.opacity(0.24)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: QuickPanelBottomTheme.cardCornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: isSelected
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
                isSelected
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
                lineWidth: isSelected ? 1.6 : 1
            )
    }

    private var headerBackground: some View {
        LinearGradient(
            colors: isSelected
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
        let base = sampledHeaderBaseColor ?? NSColor(calibratedRed: 0.30, green: 0.49, blue: 0.95, alpha: 1)
        let rgb = base.usingColorSpace(.deviceRGB) ?? base

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        if saturation < 0.12 {
            let start = NSColor(
                calibratedWhite: min(max(brightness + 0.08, 0.48), 0.92),
                alpha: 1
            )
            let end = NSColor(
                calibratedWhite: min(max(brightness - 0.04, 0.40), 0.82),
                alpha: 1
            )
            return [Color(nsColor: start), Color(nsColor: end)]
        }

        let tunedSaturation = min(max(saturation * 0.72, 0.22), 0.68)
        let start = NSColor(
            calibratedHue: hue,
            saturation: max(tunedSaturation - 0.03, 0),
            brightness: min(max(brightness + 0.02, 0.34), 0.60),
            alpha: 1
        )
        let end = NSColor(
            calibratedHue: hue,
            saturation: min(tunedSaturation + 0.03, 1),
            brightness: min(max(brightness - 0.10, 0.22), 0.48),
            alpha: 1
        )
        return [Color(nsColor: start), Color(nsColor: end)]
    }

    private var sourceAppIcon: NSImage? {
        appIcon(forBundleID: item.sourceAppBundleID, name: item.sourceApp)
    }

    private var headerColorCacheKey: String {
        "\(item.sourceAppBundleID ?? "")|\(item.sourceApp ?? "")"
    }

    @MainActor
    private var sampledHeaderBaseColor: NSColor? {
        if let cached = quickClipCardHeaderColorCache[headerColorCacheKey] {
            return cached
        }
        guard let sourceAppIcon, let color = sampleCenterColor(from: sourceAppIcon) else {
            return nil
        }
        quickClipCardHeaderColorCache[headerColorCacheKey] = color
        return color
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
        if let sourceAppIcon {
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
        } else if item.contentType == .image,
                  let data = item.imageData,
                  let image = ImageCache.shared.preview(for: data, key: item.itemID, maxDimension: imagePreviewMaxDimension) {
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
        let headerHeight: CGFloat = 56
        let footerHeight: CGFloat = 42
        let previewPadding: CGFloat = 8

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

@MainActor
private func sampleCenterColor(from image: NSImage) -> NSColor? {
    let targetSize = NSSize(width: 36, height: 36)
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(targetSize.width),
        pixelsHigh: Int(targetSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )

    guard let bitmap else { return nil }

    NSGraphicsContext.saveGraphicsState()
    if let context = NSGraphicsContext(bitmapImageRep: bitmap) {
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        context.flushGraphics()
    }
    NSGraphicsContext.restoreGraphicsState()

    let center = Int(targetSize.width / 2)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var count: CGFloat = 0

    for x in max(0, center - 2)...min(Int(targetSize.width) - 1, center + 2) {
        for y in max(0, center - 2)...min(Int(targetSize.height) - 1, center + 2) {
            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                  color.alphaComponent > 0.35 else { continue }
            red += color.redComponent
            green += color.greenComponent
            blue += color.blueComponent
            count += 1
        }
    }

    guard count > 0 else { return nil }

    return NSColor(
        calibratedRed: red / count,
        green: green / count,
        blue: blue / count,
        alpha: 1
    )
}
