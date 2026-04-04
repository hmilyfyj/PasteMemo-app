import SwiftUI

struct QuickClipCard: View {
    let item: ClipItem
    let isSelected: Bool
    let shortcutIndex: Int?
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    private let cardCornerRadius: CGFloat = 14

    init(
        item: ClipItem,
        isSelected: Bool,
        shortcutIndex: Int?,
        cardWidth: CGFloat = 198,
        cardHeight: CGFloat = 178
    ) {
        self.item = item
        self.isSelected = isSelected
        self.shortcutIndex = shortcutIndex
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            preview
            footer
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(cardBackground)
        .overlay(cardBorder)
        .shadow(color: isSelected ? Color.accentColor.opacity(0.28) : .black.opacity(0.12), radius: isSelected ? 14 : 8, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius))
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(item.contentType.label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.96))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(typeColor, in: Capsule())

            Spacer(minLength: 0)

            if let appIcon = appIcon(forBundleID: item.sourceAppBundleID, name: item.sourceApp) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 17, height: 17)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }

            if let shortcutIndex {
                Text("\(shortcutIndex)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(minWidth: 16, minHeight: 16)
                    .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 5))
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(isSelected ? 0.08 : 0.045))

            previewContent
                .padding(10)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.displayTitle ?? item.content)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.94))
                .lineLimit(3)

            Text(metaText)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .padding(.bottom, 8)
    }

    private var cardBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(isSelected ? 0.11 : 0.07),
                Color.white.opacity(isSelected ? 0.08 : 0.04),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: cardCornerRadius)
            .stroke(
                isSelected ? Color.accentColor : Color.white.opacity(0.06),
                lineWidth: isSelected ? 2 : 1
            )
    }

    private var typeColor: Color {
        switch item.contentType {
        case .text, .code: return .blue
        case .image: return .orange
        case .link: return .green
        case .video: return .purple
        case .audio: return .pink
        case .document: return .indigo
        case .archive: return .gray
        case .application: return .teal
        case .color: return .mint
        case .email: return .cyan
        case .phone: return .red
        case .file: return .brown
        }
    }

    private var metaText: String {
        let time = formatTimeAgo(item.lastUsedAt)
        switch item.contentType {
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                return "\(Int(image.size.width))×\(Int(image.size.height))"
            }
            return time
        case .file, .document, .archive, .application, .video, .audio:
            let count = item.content.split(separator: "\n").count
            return count > 1 ? L10n.tr("quick.fileCount", count) : time
        default:
            return "\(item.content.count) 字符"
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        if item.isSensitive {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 20))
                .foregroundStyle(.orange)
        } else if item.contentType == .image,
                  let data = item.imageData,
                  let image = ImageCache.shared.thumbnail(for: data, key: item.itemID) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if item.contentType == .link, let data = item.faviconData,
                  let image = ImageCache.shared.favicon(for: data, key: item.content) {
            VStack(spacing: 6) {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: 28, height: 28)
                Text(URL(string: item.content)?.host ?? item.sourceApp ?? "Link")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
        } else if item.contentType.isFileBased, let firstPath = firstPath {
            Image(nsImage: systemIcon(forFile: firstPath))
                .resizable()
                .scaledToFit()
                .padding(4)
        } else if item.contentType == .color, let parsed = ColorConverter.parse(item.content) {
            Circle()
                .fill(Color(nsColor: parsed.nsColor))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                .padding(16)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle ?? item.content)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
        }
    }

    private var firstPath: String? {
        item.content
            .split(separator: "\n")
            .first
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
