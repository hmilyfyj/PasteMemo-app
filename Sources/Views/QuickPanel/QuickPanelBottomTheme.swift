import SwiftUI
import AppKit

enum QuickPanelBottomTheme {
    static let windowCornerRadius: CGFloat = 20
    static let sectionCornerRadius: CGFloat = 16
    static let cardCornerRadius: CGFloat = 18
    static let contentInset: CGFloat = 12
    static let faintStroke = Color.white.opacity(0.06)
    static let selectionBlue = Color(red: 0.11, green: 0.38, blue: 0.90)
    static let accentBlue = Color(red: 0.16, green: 0.46, blue: 0.98)

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
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: QuickPanelBottomTheme.sectionCornerRadius, style: .continuous)
                    .fill(QuickPanelBottomTheme.sectionBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: QuickPanelBottomTheme.sectionCornerRadius, style: .continuous)
                    .stroke(QuickPanelBottomTheme.faintStroke, lineWidth: 1)
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
