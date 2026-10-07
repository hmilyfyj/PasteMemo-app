import SwiftUI
import AppKit

struct QuickPanelBottomTheme {
    let scheme: ColorScheme
    private var dark: Bool { scheme == .dark }
    var primaryText: Color { dark ? .white.opacity(0.94) : .black.opacity(0.88) }
    var controlFill: Color { dark ? .white.opacity(0.10) : .black.opacity(0.06) }
    var faintStroke: Color { dark ? .white.opacity(0.08) : .black.opacity(0.10) }
    var shellEdge: Color { .black.opacity(dark ? 0.42 : 0.12) }
    var shellShadow: Color { .black.opacity(dark ? 0.40 : 0.18) }
    var cardShadow: Color { .black.opacity(dark ? 0.20 : 0.09) }
    static let windowCornerRadius: CGFloat = 20
    static let sectionCornerRadius: CGFloat = 16
    static let cardCornerRadius: CGFloat = 18
    static let contentInset: CGFloat = 12
    static let selectionBlue = Color(red: 0.11, green: 0.38, blue: 0.90)
    static let accentBlue = Color(red: 0.16, green: 0.46, blue: 0.98)

    @MainActor
    static func headerForeground(for colors: [Color]) -> Color {
        let luminances = colors.compactMap { color -> Double? in
            guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return nil }
            func linear(_ channel: CGFloat) -> Double {
                let value = Double(channel)
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(rgb.redComponent)
                + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
        }
        guard let darkest = luminances.min(), let lightest = luminances.max() else { return .white }
        let blackContrast = (darkest + 0.05) / 0.05
        let whiteContrast = 1.05 / (lightest + 0.05)
        return blackContrast > whiteContrast ? .black : .white
    }

    var shellBackground: LinearGradient {
        LinearGradient(
            colors: [
                dark ? Color(white: 0.12).opacity(0.98) : Color(white: 0.98).opacity(0.98),
                dark ? Color(white: 0.09).opacity(0.985) : Color(white: 0.93).opacity(0.985),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var shellOverlay: LinearGradient {
        LinearGradient(
            colors: [
                dark ? Color.white.opacity(0.14) : Color.white.opacity(0.85),
                dark ? Color.white.opacity(0.02) : Color.black.opacity(0.08),
            ],
            startPoint: .topLeading,
            endPoint: .bottom
        )
    }

    var previewBackground: LinearGradient {
        LinearGradient(
            colors: [
                dark ? Color.white.opacity(0.045) : Color.white.opacity(0.8),
                dark ? Color.black.opacity(0.18) : Color.black.opacity(0.025),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var secondaryText: Color { dark ? .white.opacity(0.72) : .black.opacity(0.64) }
    var tertiaryText: Color { dark ? .white.opacity(0.5) : .black.opacity(0.54) }

    var sectionBackground: LinearGradient {
        LinearGradient(
            colors: [
                dark ? Color(white: 0.15).opacity(0.96) : Color(white: 1).opacity(0.96),
                dark ? Color(white: 0.10).opacity(0.96) : Color(white: 0.95).opacity(0.96),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @MainActor
    static func headerColor(for type: ClipContentType) -> Color {
        switch type {
        case .text, .code: return Color(red: 0.21, green: 0.45, blue: 0.97)
        case .image: return Color(red: 0.98, green: 0.48, blue: 0.02)
        case .link: return Color(red: 0.19, green: 0.67, blue: 0.39)
        case .video: return Color(red: 0.57, green: 0.41, blue: 0.97)
        case .audio: return Color(red: 0.93, green: 0.34, blue: 0.62)
        case .document: return Color(red: 0.36, green: 0.48, blue: 0.94)
        case .archive: return Color(red: 0.42, green: 0.46, blue: 0.55)
        case .application: return Color(red: 0.12, green: 0.69, blue: 0.61)
        case .color: return Color(red: 0.36, green: 0.78, blue: 0.69)
        case .email: return Color(red: 0.27, green: 0.73, blue: 0.87)
        case .phone: return Color(red: 0.96, green: 0.33, blue: 0.32)
        case .file: return Color(red: 0.60, green: 0.45, blue: 0.25)
        case .mixed: return Color(red: 0.45, green: 0.52, blue: 0.72)
        }
    }
}

private struct QuickPanelBottomShellModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    private var theme: QuickPanelBottomTheme { QuickPanelBottomTheme(scheme: scheme) }
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: QuickPanelBottomTheme.windowCornerRadius, style: .continuous)
                    .fill(theme.shellBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: QuickPanelBottomTheme.windowCornerRadius, style: .continuous)
                    .stroke(theme.shellOverlay, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: QuickPanelBottomTheme.windowCornerRadius, style: .continuous)
                    .stroke(theme.shellEdge, lineWidth: 1)
                    .blur(radius: 0.4)
            )
            .shadow(color: theme.shellShadow, radius: 24, y: 12)
    }
}

private struct QuickPanelBottomSectionModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    private var theme: QuickPanelBottomTheme { QuickPanelBottomTheme(scheme: scheme) }
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: QuickPanelBottomTheme.sectionCornerRadius, style: .continuous)
                    .fill(theme.sectionBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: QuickPanelBottomTheme.sectionCornerRadius, style: .continuous)
                    .stroke(theme.faintStroke, lineWidth: 1)
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
