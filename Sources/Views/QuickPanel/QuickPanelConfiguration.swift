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
    case togglePreview
}

enum QuickPanelKeyboardRouter {
    static func intent(
        style: QuickPanelStyle,
        bottomMode: QuickPanelBottomMode,
        keyCode: Int,
        hasCommand: Bool,
        suggestionVisible: Bool,
        searchFocused: Bool
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
        case 49 where !hasCommand && !searchFocused:
            return .togglePreview
        case 123 where !searchFocused:
            return .moveSelection(-1)
        case 124 where !searchFocused:
            return .moveSelection(1)
        case 126 where !searchFocused:
            return .switchType(-1)
        case 125 where !searchFocused:
            return .switchType(1)
        default:
            return nil
        }
    }
}

enum QuickPanelBottomGeometry {
    static let horizontalInset: CGFloat = 12
    static let legacyDefaultHorizontalInset: CGFloat = 10
    static let bottomInset: CGFloat = 10
    static let compactHeight: CGFloat = 252
    static let expandedHeight: CGFloat = 760
    static let minimumCompactHeight: CGFloat = 212
    static let minimumExpandedHeight: CGFloat = 360
    static let maxWidth: CGFloat = 10_000
    static let minimumWidth: CGFloat = 860

    static func defaultHeight(for mode: QuickPanelBottomMode) -> CGFloat {
        mode == .compact ? compactHeight : expandedHeight
    }

    static func minimumHeight(for mode: QuickPanelBottomMode) -> CGFloat {
        mode == .compact ? minimumCompactHeight : minimumExpandedHeight
    }

    static func panelWidth(for screenFrame: CGRect) -> CGFloat {
        let available = max(screenFrame.width - horizontalInset * 2, 0)
        return min(maxWidth, max(minimumWidth, available))
    }

    static func legacyDefaultWidth(for screenFrame: CGRect) -> CGFloat {
        let available = max(screenFrame.width - legacyDefaultHorizontalInset * 2, 0)
        return min(maxWidth, max(minimumWidth, available))
    }

    static func clampedWidth(_ width: CGFloat, screenFrame: CGRect) -> CGFloat {
        let available = max(screenFrame.width - horizontalInset * 2, 0)
        let lowerBound = min(minimumWidth, available)
        let upperBound = min(maxWidth, available)
        guard upperBound > 0 else { return 0 }
        return min(max(width, lowerBound), upperBound)
    }

    static func shouldUpgradeSavedWidthToCurrentDefault(_ width: CGFloat, screenFrame: CGRect) -> Bool {
        abs(width - legacyDefaultWidth(for: screenFrame)) <= 1
    }

    static func clampedHeight(_ height: CGFloat, visibleFrame: CGRect, mode: QuickPanelBottomMode) -> CGFloat {
        let available = max(visibleFrame.height - bottomInset, 0)
        let lowerBound = min(minimumHeight(for: mode), available)
        guard available > 0 else { return 0 }
        return min(max(height, lowerBound), available)
    }

    static func frame(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        mode: QuickPanelBottomMode,
        preferredWidth: CGFloat? = nil,
        preferredHeight: CGFloat? = nil
    ) -> CGRect {
        let width = clampedWidth(preferredWidth ?? panelWidth(for: screenFrame), screenFrame: screenFrame)
        let height = clampedHeight(preferredHeight ?? defaultHeight(for: mode), visibleFrame: visibleFrame, mode: mode)
        let originX = screenFrame.midX - width / 2
        let originY = visibleFrame.minY + bottomInset
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}
