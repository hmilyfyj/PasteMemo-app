import SwiftUI
import AppKit

enum QuickPanelBottomTheme {
    static let windowCornerRadius: CGFloat = 26
    static let sectionCornerRadius: CGFloat = 18
    static let cardCornerRadius: CGFloat = 20
    static let contentInset: CGFloat = 12
    static let faintStroke = Color.white.opacity(0.10)
    static let selectionBlue = Color(red: 0.11, green: 0.38, blue: 0.90)
    static let accentBlue = Color(red: 0.16, green: 0.46, blue: 0.98)

    struct Palette {
        let isDark: Bool
        let shellTop: Color
        let shellBottom: Color
        let shellStroke: Color
        let sectionFill: Color
        let sectionStroke: Color
        let cardFill: Color
        let primaryText: Color
        let secondaryText: Color
        let tertiaryText: Color
        let footerTitle: Color
        let footerMeta: Color
        let previewTop: Color
        let previewBottom: Color
        let badgeIdleFill: Color
        let badgeIdleText: Color
        let badgeActiveFill: Color
        let badgeActiveText: Color
        let footerScrim: [Color]
        let shortcutFill: Color
        let shortcutText: Color

        static func resolve(_ scheme: ColorScheme) -> Palette {
            scheme == .dark ? .dark : .light
        }

        static let light = Palette(
            isDark: false,
            shellTop: Color.white.opacity(0.46),
            shellBottom: Color(red: 0.97, green: 0.94, blue: 0.88).opacity(0.40),
            shellStroke: Color.white.opacity(0.62),
            sectionFill: Color.white.opacity(0.22),
            sectionStroke: Color.white.opacity(0.28),
            cardFill: Color.white.opacity(0.96),
            primaryText: Color(red: 0.14, green: 0.15, blue: 0.17),
            secondaryText: Color(red: 0.29, green: 0.30, blue: 0.33),
            tertiaryText: Color(red: 0.45, green: 0.46, blue: 0.49),
            footerTitle: Color(red: 0.16, green: 0.17, blue: 0.19),
            footerMeta: Color(red: 0.47, green: 0.48, blue: 0.51),
            previewTop: Color.white,
            previewBottom: Color(red: 0.97, green: 0.97, blue: 0.98),
            badgeIdleFill: Color.black.opacity(0.04),
            badgeIdleText: Color(red: 0.28, green: 0.29, blue: 0.32),
            badgeActiveFill: Color.black.opacity(0.10),
            badgeActiveText: Color(red: 0.12, green: 0.13, blue: 0.15),
            footerScrim: [Color.white.opacity(0), Color.white.opacity(0.86), Color.white.opacity(0.96)],
            shortcutFill: Color.black.opacity(0.06),
            shortcutText: Color(red: 0.24, green: 0.25, blue: 0.28)
        )

        static let dark = Palette(
            isDark: true,
            shellTop: Color(red: 0.12, green: 0.12, blue: 0.13).opacity(0.42),
            shellBottom: Color(red: 0.09, green: 0.09, blue: 0.10).opacity(0.48),
            shellStroke: Color.white.opacity(0.14),
            sectionFill: Color.white.opacity(0.05),
            sectionStroke: Color.white.opacity(0.06),
            cardFill: Color(red: 0.13, green: 0.13, blue: 0.14),
            primaryText: Color.white.opacity(0.94),
            secondaryText: Color.white.opacity(0.72),
            tertiaryText: Color.white.opacity(0.50),
            footerTitle: Color.white.opacity(0.90),
            footerMeta: Color.white.opacity(0.58),
            previewTop: Color.white.opacity(0.045),
            previewBottom: Color.black.opacity(0.18),
            badgeIdleFill: Color.white.opacity(0.06),
            badgeIdleText: Color.white.opacity(0.72),
            badgeActiveFill: Color.white.opacity(0.14),
            badgeActiveText: Color.white.opacity(0.94),
            footerScrim: [Color.clear, Color.black.opacity(0.10), Color.black.opacity(0.28)],
            shortcutFill: Color.white.opacity(0.12),
            shortcutText: Color.white.opacity(0.82)
        )
    }

    static var shellBackground: LinearGradient {
        LinearGradient(
            colors: [Palette.dark.shellTop, Palette.dark.shellBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var shellOverlay: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.14),
                Color.white.opacity(0.02),
            ],
            startPoint: .topLeading,
            endPoint: .bottom
        )
    }

    static var previewBackground: LinearGradient {
        LinearGradient(
            colors: [Palette.dark.previewTop, Palette.dark.previewBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var secondaryText: Color { Palette.dark.secondaryText }
    static var tertiaryText: Color { Palette.dark.tertiaryText }

    static var sectionBackground: LinearGradient {
        LinearGradient(
            colors: [
                Palette.dark.sectionFill,
                Palette.dark.sectionFill.opacity(0.92),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @MainActor
    static func headerColor(for type: ClipContentType) -> Color {
        PasteCardAccent.typeAccent(type).color
    }
}

private struct QuickPanelBottomShellModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let palette = QuickPanelBottomTheme.Palette.resolve(colorScheme)
        content
            .background(
                RoundedRectangle(cornerRadius: QuickPanelBottomTheme.windowCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [palette.shellTop, palette.shellBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: QuickPanelBottomTheme.windowCornerRadius, style: .continuous)
                    .stroke(palette.shellStroke, lineWidth: 1)
            )
    }
}

private struct QuickPanelBottomSectionModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let palette = QuickPanelBottomTheme.Palette.resolve(colorScheme)
        content
            .background(
                RoundedRectangle(cornerRadius: QuickPanelBottomTheme.sectionCornerRadius, style: .continuous)
                    .fill(palette.sectionFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: QuickPanelBottomTheme.sectionCornerRadius, style: .continuous)
                    .stroke(palette.sectionStroke, lineWidth: 1)
            )
    }
}

extension View {
    func quickPanelBottomShell() -> some View {
        modifier(QuickPanelBottomShellModifier())
    }

    func quickPanelBottomSection() -> some View {
        modifier(QuickPanelBottomSectionModifier())
    }
}
