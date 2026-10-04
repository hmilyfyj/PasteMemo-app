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
        return QuickPanelStyle(rawValue: raw) ?? .classic
    }

    func resetStoredSizing(in defaults: UserDefaults = .standard) {
        switch self {
        case .classic: QuickPanelBottomDefaults.resetClassicSizing(defaults: defaults)
        case .bottomFloating: QuickPanelBottomDefaults.resetStoredSizing(defaults: defaults)
        }
    }
}

enum QuickPanelBottomMode: String {
    case compact
    case expanded
}

/// Header measurements are independent of the card rail. Keep the
/// large lazy rail out of geometry feedback during AppKit's resize callbacks.
struct QuickPanelBottomContentGeometry {
    static let outerPadding: CGFloat = 8
    static let spacing: CGFloat = 4
    static let railPadding: CGFloat = 4
    static let minimumCardHeight: CGFloat = 120
    static let maximumExpandedCardHeight: CGFloat = 220
    static let minimumPreviewHeight: CGFloat = 160

    let railHeight: CGFloat
    let previewHeight: CGFloat

    var cardHeight: CGFloat { max(0, railHeight - Self.railPadding * 2) }
    var cardWidth: CGFloat { cardHeight }

    static func chromeHeight(header: CGFloat) -> CGFloat {
        header + outerPadding * 2 + spacing
    }

    static func minimumHeight(chromeHeight: CGFloat, mode: QuickPanelBottomMode) -> CGFloat {
        let content = minimumCardHeight + railPadding * 2
            + (mode == .expanded ? spacing + minimumPreviewHeight : 0)
        return max(QuickPanelBottomGeometry.minimumHeight(for: mode), chromeHeight + content)
    }

    init(panelHeight: CGFloat, chromeHeight: CGFloat, mode: QuickPanelBottomMode) {
        let available = max(0, panelHeight - chromeHeight)
        if mode == .compact {
            railHeight = available
            previewHeight = 0
        } else {
            let rail = min(
                Self.maximumExpandedCardHeight + Self.railPadding * 2,
                max(Self.minimumCardHeight + Self.railPadding * 2, available * 0.35)
            )
            railHeight = min(rail, max(0, available - Self.spacing))
            previewHeight = max(0, available - railHeight - Self.spacing)
        }
    }
}

enum QuickPanelBottomGeometry {
    static let edgeGap: CGFloat = 12
    static let horizontalInset: CGFloat = edgeGap
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
        return min(maxWidth, available)
    }

    static func clampedWidth(_ width: CGFloat, screenFrame: CGRect) -> CGFloat {
        let available = max(screenFrame.width - horizontalInset * 2, 0)
        let lowerBound = min(minimumWidth, available)
        let upperBound = min(maxWidth, available)
        guard upperBound > 0 else { return 0 }
        return min(max(width, lowerBound), upperBound)
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
        let width = clampedWidth(preferredWidth ?? panelWidth(for: visibleFrame), screenFrame: visibleFrame)
        let height = clampedHeight(
            preferredHeight ?? defaultHeight(for: mode, visibleFrame: visibleFrame),
            visibleFrame: visibleFrame,
            mode: mode
        )
        let originX = visibleFrame.minX + horizontalInset
        let originY = visibleFrame.minY + bottomInset
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}

enum QuickPanelBottomDefaults {
    static let sizeStorageKey = "quickPanelBottomSize"
    static let widthIsCustomKey = "quickPanelBottomWidthIsCustom"
    static let modeStorageKey = "quickPanelBottomMode"
    static let fullBleedMigrationKey = "quickPanelBottomFullBleedWidth.v2"

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

    static func migrateDefaultWidthIfNeeded(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: fullBleedMigrationKey) else { return }
        defaults.removeObject(forKey: "\(sizeStorageKey).width")
        defaults.set(false, forKey: widthIsCustomKey)
        defaults.set(true, forKey: fullBleedMigrationKey)
    }

    static func storedWidth(defaults: UserDefaults = .standard) -> CGFloat? {
        migrateDefaultWidthIfNeeded(defaults: defaults)
        guard defaults.bool(forKey: widthIsCustomKey) else { return nil }
        let value = defaults.double(forKey: "\(sizeStorageKey).width")
        return value > 0 ? value : nil
    }

    static func storedHeight(for mode: QuickPanelBottomMode, defaults: UserDefaults = .standard) -> CGFloat? {
        let value = defaults.double(forKey: "\(sizeStorageKey).\(mode.rawValue).height")
        return value > 0 ? value : nil
    }

    static func persist(size: CGSize, mode: QuickPanelBottomMode, screenFrame: CGRect, defaults: UserDefaults = .standard) {
        let defaultWidth = QuickPanelBottomGeometry.panelWidth(for: screenFrame)
        defaults.set(abs(size.width - defaultWidth) > 1, forKey: widthIsCustomKey)
        defaults.set(Double(size.width), forKey: "\(sizeStorageKey).width")
        defaults.set(Double(size.height), forKey: "\(sizeStorageKey).\(mode.rawValue).height")
    }
}
