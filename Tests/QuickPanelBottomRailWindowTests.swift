import Testing
@testable import PasteMemo

@Suite("QuickPanelBottomRailWindow")
struct QuickPanelBottomRailWindowTests {

    @Test("Empty list yields an empty range")
    func emptyList() {
        #expect(QuickPanelBottomRailWindow.range(itemCount: 0, selectedIndex: 0, grownCount: 40) == 0..<0)
        #expect(QuickPanelBottomRailWindow.range(itemCount: 0, selectedIndex: 8, grownCount: 40) == 0..<0)
    }

    @Test("Short lists stay fully in range")
    func shortList() {
        #expect(QuickPanelBottomRailWindow.range(itemCount: 10, selectedIndex: 0, grownCount: 40) == 0..<10)
        #expect(QuickPanelBottomRailWindow.range(itemCount: 10, selectedIndex: 9, grownCount: 40) == 0..<10)
    }

    @Test("Selection near the start grows from zero")
    func growFromStart() {
        #expect(QuickPanelBottomRailWindow.range(itemCount: 100, selectedIndex: 0, grownCount: 40) == 0..<40)
        #expect(QuickPanelBottomRailWindow.range(itemCount: 100, selectedIndex: 10, grownCount: 40) == 0..<40)
        #expect(QuickPanelBottomRailWindow.range(itemCount: 100, selectedIndex: 39, grownCount: 40) == 0..<40)
        #expect(QuickPanelBottomRailWindow.range(itemCount: 100, selectedIndex: 10, grownCount: 56) == 0..<56)
    }

    @Test("Distant selection recenters with a leading buffer")
    func recenterOnJump() {
        #expect(QuickPanelBottomRailWindow.range(itemCount: 100, selectedIndex: 50, grownCount: 40) == 34..<74)
        #expect(QuickPanelBottomRailWindow.range(itemCount: 100, selectedIndex: 99, grownCount: 40) == 83..<100)
    }

    @Test("Selected index is clamped and always contained")
    func clampsAndContainsSelection() {
        let overflow = QuickPanelBottomRailWindow.range(itemCount: 100, selectedIndex: 200, grownCount: 40)
        #expect(overflow == 83..<100)
        #expect(overflow.contains(99))

        let negative = QuickPanelBottomRailWindow.range(itemCount: 100, selectedIndex: -4, grownCount: 40)
        #expect(negative == 0..<40)
        #expect(negative.contains(0))
    }
}
