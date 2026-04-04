import AppKit
import Foundation

enum QuickPanelStyle: String, CaseIterable {
    case classic
    case bottomFloating

    static let storageKey = "quickPanelStyle"

    static var stored: QuickPanelStyle {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? QuickPanelStyle.classic.rawValue
        return QuickPanelStyle(rawValue: raw) ?? .classic
    }
}

enum QuickPanelBottomMode: String {
    case compact
    case expanded
}

enum QuickPanelKeyIntent: Equatable {
    case moveSelection(Int)
    case switchType(Int)
    case toggleBottomMode
    case collapseOrDismiss
    case focusSearch
}

enum QuickPanelKeyboardRouter {
    static func intent(
        style: QuickPanelStyle,
        bottomMode: QuickPanelBottomMode,
        keyCode: Int,
        hasCommand: Bool,
        suggestionVisible: Bool
    ) -> QuickPanelKeyIntent? {
        guard !suggestionVisible else { return nil }

        switch keyCode {
        case 3 where hasCommand:
            return .focusSearch
        case 31 where hasCommand && style == .bottomFloating:
            return .toggleBottomMode
        case 53 where style == .bottomFloating && bottomMode == .expanded:
            return .collapseOrDismiss
        default:
            break
        }

        guard style == .bottomFloating else { return nil }

        switch keyCode {
        case 123:
            return .moveSelection(-1)
        case 124:
            return .moveSelection(1)
        case 126:
            return .switchType(-1)
        case 125:
            return .switchType(1)
        default:
            return nil
        }
    }
}

enum QuickPanelBottomGeometry {
    static let horizontalInset: CGFloat = 16
    static let bottomInset: CGFloat = 20
    static let compactHeight: CGFloat = 260
    static let expandedHeight: CGFloat = 640
    static let maxWidth: CGFloat = 2200
    static let minimumWidth: CGFloat = 900

    static func panelWidth(for visibleFrame: CGRect) -> CGFloat {
        let available = max(visibleFrame.width - horizontalInset * 2, 0)
        return min(maxWidth, max(minimumWidth, available))
    }

    static func frame(in visibleFrame: CGRect, mode: QuickPanelBottomMode) -> CGRect {
        let width = min(panelWidth(for: visibleFrame), visibleFrame.width - horizontalInset * 2)
        let height = mode == .compact ? compactHeight : expandedHeight
        let originX = visibleFrame.midX - width / 2
        let originY = visibleFrame.minY + bottomInset
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}
