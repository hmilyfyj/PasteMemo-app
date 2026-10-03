import Foundation
import Testing
@testable import PasteMemo

@Suite("Bottom panel content sizing and preferences")
struct QuickPanelBottomGeometryTests {
    @Test("cards remain square in both modes across viewport heights",
          arguments: [CGFloat(0), 212, 252, 401, 760, 1000],
          [QuickPanelBottomMode.compact, .expanded])
    func cardsRemainSquare(height: CGFloat, mode: QuickPanelBottomMode) {
        let chrome = QuickPanelBottomContentGeometry.chromeHeight(header: 49)
        let content = QuickPanelBottomContentGeometry(panelHeight: height, chromeHeight: chrome, mode: mode)
        #expect(content.cardWidth == content.cardHeight)
        #expect(content.cardWidth >= 0)
    }

    @Test("compact cards fill the height below the toolbar with no footer", arguments: [CGFloat(22), 49, 82])
    func compactFitsMeasuredChrome(header: CGFloat) {
        let chrome = QuickPanelBottomContentGeometry.chromeHeight(header: header)
        let height = QuickPanelBottomContentGeometry.minimumHeight(chromeHeight: chrome, mode: .compact) + 180
        let content = QuickPanelBottomContentGeometry(panelHeight: height, chromeHeight: chrome, mode: .compact)
        #expect(content.railHeight + chrome == height)
        #expect(content.previewHeight == 0)
        #expect(content.cardHeight + QuickPanelBottomContentGeometry.railPadding * 2 == content.railHeight)
        #expect(header + 8 * 2 + 4 + content.railHeight == height)
    }

    @Test("expanded minimum fits cards and preview below the toolbar", arguments: [CGFloat(22), 49, 82])
    func expandedMinimumFitsBothSections(header: CGFloat) {
        let chrome = QuickPanelBottomContentGeometry.chromeHeight(header: header)
        let height = QuickPanelBottomContentGeometry.minimumHeight(chromeHeight: chrome, mode: .expanded)
        let content = QuickPanelBottomContentGeometry(panelHeight: height, chromeHeight: chrome, mode: .expanded)
        #expect(content.cardHeight >= QuickPanelBottomContentGeometry.minimumCardHeight)
        #expect(content.previewHeight >= QuickPanelBottomContentGeometry.minimumPreviewHeight)
        #expect(content.railHeight + content.previewHeight + QuickPanelBottomContentGeometry.spacing + chrome == height)
    }

    @Test("extra expanded height goes to the preview instead of oversized cards")
    func expandedGrowthGoesToPreview() {
        let chrome = QuickPanelBottomContentGeometry.chromeHeight(header: 49)
        let shorter = QuickPanelBottomContentGeometry(panelHeight: 760, chromeHeight: chrome, mode: .expanded)
        let taller = QuickPanelBottomContentGeometry(panelHeight: 1000, chromeHeight: chrome, mode: .expanded)
        #expect(shorter.cardHeight <= QuickPanelBottomContentGeometry.maximumExpandedCardHeight)
        #expect(taller.cardHeight <= QuickPanelBottomContentGeometry.maximumExpandedCardHeight)
        #expect(taller.previewHeight > shorter.previewHeight)
        #expect(taller.railHeight + taller.previewHeight + QuickPanelBottomContentGeometry.spacing + chrome == 1000)
    }

    @Test("an undersized transient viewport produces no negative section sizes", arguments: [CGFloat(0), 50, 125])
    func undersizedViewport(height: CGFloat) {
        let content = QuickPanelBottomContentGeometry(panelHeight: height, chromeHeight: 120, mode: .expanded)
        #expect(content.railHeight >= 0)
        #expect(content.previewHeight >= 0)
        #expect(content.cardHeight >= 0)
        #expect(content.railHeight + content.previewHeight <= max(0, height - 120))
    }

    @Test("reset only removes the chosen style's sizes", arguments: QuickPanelStyle.allCases)
    func resetIsIsolatedToStyle(style: QuickPanelStyle) throws {
        let suite = "QuickPanelBottomGeometryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(930, forKey: "quickPanelSize.width")
        defaults.set(640, forKey: "quickPanelSize.height")
        defaults.set(true, forKey: QuickPanelBottomDefaults.fullBleedMigrationKey)
        defaults.set(QuickPanelBottomMode.expanded.rawValue, forKey: QuickPanelBottomDefaults.modeStorageKey)
        QuickPanelBottomDefaults.persist(size: CGSize(width: 1100, height: 310), mode: .compact,
                                        screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900), defaults: defaults)
        QuickPanelBottomDefaults.persist(size: CGSize(width: 1100, height: 800), mode: .expanded,
                                        screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900), defaults: defaults)

        // Selecting either style reads preferences without resetting either namespace.
        for selectedStyle in QuickPanelStyle.allCases {
            defaults.set(selectedStyle.rawValue, forKey: QuickPanelStyle.storageKey)
            #expect(QuickPanelStyle.stored(in: defaults) == selectedStyle)
            #expect(defaults.double(forKey: "quickPanelSize.width") == 930)
            #expect(QuickPanelBottomDefaults.storedWidth(defaults: defaults) == 1100)
        }

        style.resetStoredSizing(in: defaults)
        if style == .classic {
            #expect(defaults.object(forKey: "quickPanelSize.width") == nil)
            #expect(defaults.object(forKey: "quickPanelSize.height") == nil)
            #expect(QuickPanelBottomDefaults.storedWidth(defaults: defaults) == 1100)
            #expect(QuickPanelBottomDefaults.storedHeight(for: .compact, defaults: defaults) == 310)
            #expect(QuickPanelBottomDefaults.storedHeight(for: .expanded, defaults: defaults) == 800)
        } else {
            #expect(defaults.double(forKey: "quickPanelSize.width") == 930)
            #expect(defaults.double(forKey: "quickPanelSize.height") == 640)
            #expect(QuickPanelBottomDefaults.storedWidth(defaults: defaults) == nil)
            #expect(QuickPanelBottomDefaults.storedHeight(for: .compact, defaults: defaults) == nil)
            #expect(QuickPanelBottomDefaults.storedHeight(for: .expanded, defaults: defaults) == nil)
        }
        #expect(defaults.string(forKey: QuickPanelBottomDefaults.modeStorageKey) == "expanded")
    }
}
