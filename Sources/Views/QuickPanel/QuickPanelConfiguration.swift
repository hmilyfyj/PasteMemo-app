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
}

enum QuickPanelBottomMode: String {
    case compact
    case expanded
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

    /// Vertical chrome that sits outside the card rail.
    /// Keep this in sync with `bottomFloatingLayout` / `searchBar` / `tabBar` / `footerBar`.
    static let outerPadding: CGFloat = 8
    static let stackSpacing: CGFloat = 4
    static let searchHeight: CGFloat = 22
    static let tabBarHeight: CGFloat = 24
    static let footerHeight: CGFloat = 40
    static let railInnerPadding: CGFloat = 8
    static let chromeSlack: CGFloat = 8

    /// Space left for square cards after search, tabs, footer and paddings.
    static func cardSide(panelHeight: CGFloat, expanded: Bool) -> CGFloat {
        let gaps = expanded ? 4 : 3
        let reserved = outerPadding * 2
            + searchHeight
            + tabBarHeight
            + footerHeight
            + stackSpacing * CGFloat(gaps)
            + railInnerPadding
            + chromeSlack
        let remaining = panelHeight - reserved
        let railHeight = expanded ? remaining / 2 : remaining
        return max(railHeight, 1)
    }

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
