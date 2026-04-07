import AppKit
import Foundation

enum QuickPanelStyle: String, CaseIterable {
    case classic
    case bottomFloating

    static let storageKey = "quickPanelStyle"

    static var stored: QuickPanelStyle {
        stored(in: .standard)
    }

    static func stored(in defaults: UserDefaults) -> QuickPanelStyle {
        let raw = defaults.string(forKey: storageKey) ?? QuickPanelStyle.classic.rawValue
        return QuickPanelStyle(rawValue: raw) ?? .bottomFloating
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
    static let edgeGap: CGFloat = 10
    static let horizontalInset: CGFloat = 0
    static let legacyDefaultHorizontalInset: CGFloat = edgeGap
    static let bottomInset: CGFloat = edgeGap
    static let compactHeight: CGFloat = 252
    static let expandedHeight: CGFloat = 760
    static let minimumCompactHeight: CGFloat = 212
    static let minimumExpandedHeight: CGFloat = 360
    static let maxWidth: CGFloat = 10_000
    static let minimumWidth: CGFloat = 860
    static let defaultCompactHeightRatio: CGFloat = 0.25

    static func defaultHeight(for mode: QuickPanelBottomMode, visibleFrame: CGRect? = nil) -> CGFloat {
        if let visibleFrame {
            switch mode {
            case .compact:
                return visibleFrame.height * defaultCompactHeightRatio
            case .expanded:
                return expandedHeight
            }
        }
        return mode == .compact ? compactHeight : expandedHeight
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
        let height = clampedHeight(preferredHeight ?? defaultHeight(for: mode, visibleFrame: visibleFrame), visibleFrame: visibleFrame, mode: mode)
        let originX = screenFrame.midX - width / 2
        let originY = visibleFrame.minY + bottomInset
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}

enum QuickPanelBottomDefaults {
    static let sizeStorageKey = "quickPanelBottomSize"
    static let widthIsCustomKey = "quickPanelBottomWidthIsCustom"

    static func resetStoredSizing(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: "\(sizeStorageKey).width")
        defaults.removeObject(forKey: "\(sizeStorageKey).compact.height")
        defaults.removeObject(forKey: "\(sizeStorageKey).expanded.height")
        defaults.set(false, forKey: widthIsCustomKey)
    }

    static func resetClassicSizing(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: "quickPanelSize.width")
        defaults.removeObject(forKey: "quickPanelSize.height")
    }
}

enum QuickPanelSizePersistence {
    static func persist(
        size: CGSize,
        style: QuickPanelStyle,
        bottomMode: QuickPanelBottomMode,
        screenFrame: CGRect?,
        defaults: UserDefaults = .standard
    ) {
        switch style {
        case .bottomFloating:
            let resolvedScreenFrame = screenFrame ?? .zero
            let defaultWidth = QuickPanelBottomGeometry.panelWidth(for: resolvedScreenFrame)
            let widthIsCustom = abs(size.width - defaultWidth) > 1
            defaults.set(widthIsCustom, forKey: QuickPanelBottomDefaults.widthIsCustomKey)
            defaults.set(Double(size.width), forKey: "\(QuickPanelBottomDefaults.sizeStorageKey).width")
            defaults.set(
                Double(size.height),
                forKey: "\(QuickPanelBottomDefaults.sizeStorageKey).\(bottomMode.rawValue).height"
            )

        case .classic:
            defaults.set(Double(size.width), forKey: "quickPanelSize.width")
            defaults.set(Double(size.height), forKey: "quickPanelSize.height")
        }
    }
}

enum QuickPanelBottomAnimation {
    static let revealHeight: CGFloat = 28
    static let openOvershoot: CGFloat = 0
    static let openDuration: TimeInterval = 0.22
    static let settleDuration: TimeInterval = 0.14
    static let closeRevealHeight: CGFloat = 20
    static let closeDuration: TimeInterval = 0.18
    static let closedAlpha: CGFloat = 0.94
    static let openAlpha: CGFloat = 1

    static let emergeDuration: TimeInterval = 0.25
    static let emergeSettleDuration: TimeInterval = 0.15
    static let emergeFinalOffset: CGFloat = 10

    static func openingInitialOffset(for panelHeight: CGFloat) -> CGFloat {
        -(max(panelHeight - revealHeight, 0))
    }

    static func closingTargetOffset(for panelHeight: CGFloat) -> CGFloat {
        -(max(panelHeight - closeRevealHeight, 0))
    }
}
