import SwiftUI
import AppKit

enum QuickPanelBottomTheme {
    static let windowCornerRadius: CGFloat = 22
    static let sectionCornerRadius: CGFloat = 18
    static let cardCornerRadius: CGFloat = 22
    static let previewCornerRadius: CGFloat = 20
    static let shellInset: CGFloat = 0
    static let contentInset: CGFloat = 12
    static let thinStroke = Color.white.opacity(0.08)
    static let faintStroke = Color.white.opacity(0.05)
    static let selectionBlue = Color(red: 0.17, green: 0.50, blue: 1.0)
    static let accentBlue = Color(red: 0.24, green: 0.54, blue: 1.0)
    static let searchWidth: CGFloat = 360
    static let searchMinWidth: CGFloat = 240
    static let searchHeight: CGFloat = 32

    static var shellBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.13, green: 0.13, blue: 0.14).opacity(0.98),
                Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0.98),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var shellOverlay: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.12),
                Color.white.opacity(0.03),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var sectionBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.065),
                Color.white.opacity(0.03),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var previewBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.05),
                Color.black.opacity(0.12),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var controlFill: Color { Color.white.opacity(0.055) }
    static var mutedFill: Color { Color.white.opacity(0.035) }
    static var glassFill: Color { Color.white.opacity(0.025) }
    static var secondaryText: Color { Color.white.opacity(0.7) }
    static var tertiaryText: Color { Color.white.opacity(0.52) }

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
                    .stroke(Color.black.opacity(0.35), lineWidth: 1)
                    .blur(radius: 0.4)
            )
            .shadow(color: .black.opacity(0.32), radius: 30, y: 18)
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
