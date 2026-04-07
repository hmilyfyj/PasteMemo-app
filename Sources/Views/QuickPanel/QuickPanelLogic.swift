import SwiftUI
import SwiftData

struct QuickPanelGroupSuggestion: Equatable {
    let name: String
    let icon: String
    let count: Int
}

struct QuickPanelAppSuggestion: Equatable {
    let name: String
    let count: Int
}

enum QuickPanelSearchLogic {
    static func suggestionQuery(for searchText: String, prefix: String = "/") -> String? {
        guard searchText.hasPrefix(prefix) else { return nil }
        guard !shouldTreatAsPathQuery(searchText, prefix: prefix) else { return nil }
        return String(searchText.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces).lowercased()
    }

    static func shouldTreatAsPathQuery(_ searchText: String, prefix: String = "/") -> Bool {
        guard searchText.hasPrefix(prefix) else { return false }
        return searchText.filter { $0 == Character(prefix) }.count > prefix.count
    }

    static func shouldShowSuggestions(
        selectedGroupFilter: String?,
        searchText: String,
        groupCount: Int,
        appCount: Int,
        prefix: String = "/"
    ) -> Bool {
        guard selectedGroupFilter == nil else { return false }
        guard suggestionQuery(for: searchText, prefix: prefix) != nil else { return false }
        return groupCount > 0 || appCount > 0
    }

    static func matchingGroupSuggestions(
        query: String,
        groups: [QuickPanelGroupSuggestion]
    ) -> [QuickPanelGroupSuggestion] {
        groups.filter { group in
            query.isEmpty || group.name.lowercased().contains(query)
        }
    }

    static func matchingAppSuggestions(
        query: String,
        apps: [String],
        counts: [String: Int]
    ) -> [QuickPanelAppSuggestion] {
        let results = apps
            .filter { !$0.isEmpty }
            .compactMap { name -> QuickPanelAppSuggestion? in
                let count = counts[name] ?? 0
                guard count > 0 else { return nil }
                guard query.isEmpty || name.lowercased().contains(query) else { return nil }
                return QuickPanelAppSuggestion(name: name, count: count)
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.count > rhs.count
            }

        return query.isEmpty ? Array(results.prefix(5)) : results
    }
}

enum QuickPanelSelectionLogic {
    static func bottomClipScrollAnchor<ID: Equatable>(
        ids: [ID],
        targetID: ID,
        previousID: ID?,
        allowsDirectionalFallback: Bool
    ) -> UnitPoint? {
        guard allowsDirectionalFallback else { return nil }
        guard let targetIndex = ids.firstIndex(of: targetID) else { return .leading }
        guard let previousID, let previousIndex = ids.firstIndex(of: previousID) else {
            return .leading
        }

        if targetIndex < previousIndex {
            return .leading
        }
        if targetIndex > previousIndex {
            return .trailing
        }
        return nil
    }

    static func visibleSliceBounds<ID: Equatable>(
        itemIDs: [ID],
        focusedID: ID?,
        maxVisibleItems: Int
    ) -> Range<Int> {
        guard !itemIDs.isEmpty else { return 0..<0 }
        guard itemIDs.count > maxVisibleItems else { return itemIDs.startIndex..<itemIDs.endIndex }
        guard let focusedID,
              let focusIndex = itemIDs.firstIndex(of: focusedID) else {
            return 0..<maxVisibleItems
        }

        let leadingCount = maxVisibleItems / 2
        let unclampedStart = focusIndex - leadingCount
        let maxStart = max(itemIDs.count - maxVisibleItems, 0)
        let start = min(max(unclampedStart, 0), maxStart)
        let end = min(start + maxVisibleItems, itemIDs.count)
        return start..<end
    }
}
