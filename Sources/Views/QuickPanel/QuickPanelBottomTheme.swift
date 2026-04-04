import SwiftUI
import AppKit

enum QuickPanelBottomTheme {
    static let windowCornerRadius: CGFloat = 20
    static let sectionCornerRadius: CGFloat = 16
    static let cardCornerRadius: CGFloat = 18
    static let previewCornerRadius: CGFloat = 18
    static let shellInset: CGFloat = 0
    static let contentInset: CGFloat = 12
    static let thinStroke = Color.white.opacity(0.09)
    static let faintStroke = Color.white.opacity(0.06)
    static let selectionBlue = Color(red: 0.11, green: 0.38, blue: 0.90)
    static let accentBlue = Color(red: 0.16, green: 0.46, blue: 0.98)
    static let searchWidth: CGFloat = 360
    static let searchMinWidth: CGFloat = 240
    static let searchHeight: CGFloat = 32

    static var shellBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.12, green: 0.12, blue: 0.13).opacity(0.98),
                Color(red: 0.09, green: 0.09, blue: 0.10).opacity(0.985),
            ],
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

    static var sectionBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.15, green: 0.15, blue: 0.16).opacity(0.96),
                Color(red: 0.10, green: 0.10, blue: 0.11).opacity(0.96),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var previewBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.045),
                Color.black.opacity(0.18),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var controlFill: Color { Color.white.opacity(0.07) }
    static var mutedFill: Color { Color.white.opacity(0.045) }
    static var glassFill: Color { Color.white.opacity(0.03) }
    static var secondaryText: Color { Color.white.opacity(0.72) }
    static var tertiaryText: Color { Color.white.opacity(0.5) }
    static var toolbarChipFill: Color { Color.white.opacity(0.055) }

    private static let groupPalette: [Color] = [
        Color(red: 1.00, green: 0.33, blue: 0.31),
        Color(red: 0.78, green: 0.23, blue: 0.90),
        Color(red: 1.00, green: 0.73, blue: 0.11),
        Color(red: 0.22, green: 0.82, blue: 0.39),
        Color(red: 0.56, green: 0.60, blue: 0.66),
        Color(red: 0.15, green: 0.69, blue: 0.98),
        Color(red: 1.00, green: 0.56, blue: 0.15),
        Color(red: 0.29, green: 0.84, blue: 0.75),
    ]

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
        }
    }

    static func groupTintColor(name: String, preferredHex: String?) -> Color {
        if let preferredHex, let parsed = color(from: preferredHex) {
            return parsed
        }
        let index = stableColorIndex(for: name)
        return groupPalette[index]
    }

    private static func stableColorIndex(for name: String) -> Int {
        let value = name.unicodeScalars.reduce(5381) { partial, scalar in
            ((partial << 5) &+ partial) &+ Int(scalar.value)
        }
        return abs(value) % groupPalette.count
    }

    private static func color(from hex: String) -> Color? {
        let sanitized = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard sanitized.count == 6 || sanitized.count == 8 else { return nil }
        guard let value = UInt64(sanitized, radix: 16) else { return nil }

        let red, green, blue, alpha: Double
        if sanitized.count == 8 {
            red = Double((value >> 24) & 0xFF) / 255
            green = Double((value >> 16) & 0xFF) / 255
            blue = Double((value >> 8) & 0xFF) / 255
            alpha = Double(value & 0xFF) / 255
        } else {
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
            alpha = 1
        }

        return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

struct QuickPanelBottomCheckerboard: View {
    var cellSize: CGFloat = 10
    var cornerRadius: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            let even = Color.white.opacity(0.08)
            let odd = Color.white.opacity(0.03)

            for row in stride(from: 0 as CGFloat, to: size.height + cellSize, by: cellSize) {
                for column in stride(from: 0 as CGFloat, to: size.width + cellSize, by: cellSize) {
                    let isEven = (Int(row / cellSize) + Int(column / cellSize)).isMultiple(of: 2)
                    context.fill(
                        Path(CGRect(x: column, y: row, width: cellSize, height: cellSize)),
                        with: .color(isEven ? even : odd)
                    )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct QuickPanelBottomShellModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: QuickPanelBottomTheme.windowCornerRadius, style: .continuous)
                    .fill(QuickPanelBottomTheme.shellBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: QuickPanelBottomTheme.windowCornerRadius, style: .continuous)
                    .stroke(QuickPanelBottomTheme.shellOverlay, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: QuickPanelBottomTheme.windowCornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.42), lineWidth: 1)
                    .blur(radius: 0.4)
            )
            .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
    }
}

private struct QuickPanelBottomSectionModifier: ViewModifier {
    var showBorder: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: QuickPanelBottomTheme.sectionCornerRadius, style: .continuous)
                    .fill(QuickPanelBottomTheme.sectionBackground)
            )
            .overlay {
                if showBorder {
                    RoundedRectangle(cornerRadius: QuickPanelBottomTheme.sectionCornerRadius, style: .continuous)
                        .stroke(QuickPanelBottomTheme.faintStroke, lineWidth: 1)
                }
            }
    }
}

extension View {
    func quickPanelBottomShell() -> some View {
        modifier(QuickPanelBottomShellModifier())
    }

    func quickPanelBottomSection(showBorder: Bool = true) -> some View {
        modifier(QuickPanelBottomSectionModifier(showBorder: showBorder))
    }
}
