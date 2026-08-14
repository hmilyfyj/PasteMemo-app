import SwiftUI
import AppKit

struct QuickClipCard: View {
    let item: ClipItem
    let isSelected: Bool
    let shortcutIndex: Int?
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    var searchText: String = ""

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
        HStack(spacing: 8) {
            Image(systemName: item.contentType.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.contentType.label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(formatTimeAgo(item.lastUsedAt))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let shortcutIndex {
                Text("⌘\(shortcutIndex)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.2)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(QuickPanelBottomTheme.headerColor(for: item.contentType).opacity(isSelected ? 0.95 : 0.82))
    }

    @ViewBuilder
    private var preview: some View {
        ZStack {
            if item.contentType == .image, let data = item.imageData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else if item.contentType == .color, let color = Color(hex: item.content) {
                color
            } else {
                Text(previewText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .multilineTextAlignment(.leading)
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .overlay(alignment: .topLeading) {
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(6)
            }
        }
    }

    private var previewText: String {
        let raw = item.displayTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty { return raw }
        return item.content
    }

    private var cardBackground: some View {
        LinearGradient(
            colors: isSelected
                ? [QuickPanelBottomTheme.accentBlue.opacity(0.28), Color(red: 0.10, green: 0.11, blue: 0.14)]
                : [Color(red: 0.11, green: 0.11, blue: 0.12), Color(red: 0.08, green: 0.08, blue: 0.09)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: QuickPanelBottomTheme.cardCornerRadius, style: .continuous)
            .stroke(
                isSelected ? QuickPanelBottomTheme.selectionBlue.opacity(0.7) : Color.white.opacity(0.06),
                lineWidth: isSelected ? 1.5 : 1
            )
    }
}
