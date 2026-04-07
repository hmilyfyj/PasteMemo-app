import SwiftUI
import Testing
@testable import PasteMemo

@Suite("QuickPanel View Logic Tests")
struct QuickPanelViewLogicTests {
    @Test("Slash query shows matching group suggestions")
    func slashQueryMatchesGroups() {
        let groups = [
            QuickPanelGroupSuggestion(name: "Work", icon: "briefcase", count: 8),
            QuickPanelGroupSuggestion(name: "Personal", icon: "house", count: 3),
        ]

        let query = QuickPanelSearchLogic.suggestionQuery(for: "/wo")
        #expect(query == "wo")
        #expect(
            QuickPanelSearchLogic.matchingGroupSuggestions(
                query: query ?? "",
                groups: groups
            ) == [groups[0]]
        )
        #expect(
            QuickPanelSearchLogic.shouldShowSuggestions(
                selectedGroupFilter: nil,
                searchText: "/wo",
                groupCount: 1,
                appCount: 0
            )
        )
    }

    @Test("Path-like slash query does not enter suggestion mode")
    func pathLikeSlashQuerySkipsSuggestions() {
        #expect(QuickPanelSearchLogic.shouldTreatAsPathQuery("/Users/fengit/Documents"))
        #expect(QuickPanelSearchLogic.suggestionQuery(for: "/Users/fengit/Documents") == nil)
        #expect(
            !QuickPanelSearchLogic.shouldShowSuggestions(
                selectedGroupFilter: nil,
                searchText: "/Users/fengit/Documents",
                groupCount: 3,
                appCount: 2
            )
        )
    }

    @Test("App suggestions sort by count and limit empty query")
    func appSuggestionsSortByCount() {
        let suggestions = QuickPanelSearchLogic.matchingAppSuggestions(
            query: "",
            apps: ["Safari", "Xcode", "WeChat", "Terminal", ""],
            counts: [
                "Safari": 2,
                "Xcode": 9,
                "WeChat": 5,
                "Terminal": 4,
            ]
        )

        #expect(suggestions.map(\.name) == ["Xcode", "WeChat", "Terminal", "Safari"])
    }

    @Test("Bottom clip anchor follows navigation direction")
    func bottomClipAnchorTracksDirection() {
        let ids = [1, 2, 3, 4]

        #expect(
            QuickPanelSelectionLogic.bottomClipScrollAnchor(
                ids: ids,
                targetID: 1,
                previousID: 2,
                allowsDirectionalFallback: true
            ) == .leading
        )
        #expect(
            QuickPanelSelectionLogic.bottomClipScrollAnchor(
                ids: ids,
                targetID: 4,
                previousID: 2,
                allowsDirectionalFallback: true
            ) == .trailing
        )
        #expect(
            QuickPanelSelectionLogic.bottomClipScrollAnchor(
                ids: ids,
                targetID: 2,
                previousID: 2,
                allowsDirectionalFallback: true
            ) == nil
        )
        #expect(
            QuickPanelSelectionLogic.bottomClipScrollAnchor(
                ids: ids,
                targetID: 2,
                previousID: 1,
                allowsDirectionalFallback: false
            ) == nil
        )
    }

    @Test("Live resize slice centers around focused item when possible")
    func liveResizeSliceFollowsFocus() {
        let bounds = QuickPanelSelectionLogic.visibleSliceBounds(
            itemIDs: Array(0..<15),
            focusedID: 8,
            maxVisibleItems: 10
        )

        #expect(bounds == 3..<13)
        #expect(
            QuickPanelSelectionLogic.visibleSliceBounds(
                itemIDs: Array(0..<6),
                focusedID: 4,
                maxVisibleItems: 10
            ) == 0..<6
        )
    }
}
