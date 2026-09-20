import CoreGraphics
import Testing
@testable import PasteMemo

@Suite("Bottom floating card geometry")
struct QuickPanelBottomGeometryTests {

    @Test("compact square cards stay inside the rail")
    func compactCardsFit() {
        let panelHeight: CGFloat = 389
        let side = QuickPanelBottomGeometry.cardSide(panelHeight: panelHeight, expanded: false)
        #expect(side > 200)
        #expect(side <= panelHeight - 118)
    }

    @Test("card side never exceeds the remaining rail height")
    func neverTallerThanRail() {
        for height in stride(from: 212 as CGFloat, through: 760, by: 40) {
            let compact = QuickPanelBottomGeometry.cardSide(panelHeight: height, expanded: false)
            let expanded = QuickPanelBottomGeometry.cardSide(panelHeight: height, expanded: true)
            #expect(compact < height)
            #expect(expanded < compact)
            #expect(compact + 100 <= height)
        }
    }

    @Test("old 100pt chrome would overflow a 389pt compact panel")
    func oldChromeOverflows() {
        let panelHeight: CGFloat = 389
        let oldSide = panelHeight - 100
        let newSide = QuickPanelBottomGeometry.cardSide(panelHeight: panelHeight, expanded: false)
        #expect(newSide < oldSide)
        #expect(oldSide - newSide >= 18)
    }
}
