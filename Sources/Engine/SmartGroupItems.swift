import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Shared membership and ordering operations for both windows. History timestamps
/// are never changed here; a group's manual ordering is independent of pasting.
@MainActor
enum SmartGroupItems {
    static func ordered(_ items: [ClipItem]) -> [ClipItem] {
        items.sorted {
            switch ($0.groupSortOrder, $1.groupSortOrder) {
            case let (left?, right?) where left != right: return left < right
            case (_?, nil): return true
            case (nil, _?): return false
            default:
                if $0.lastUsedAt != $1.lastUsedAt { return $0.lastUsedAt > $1.lastUsedAt }
                return $0.itemID < $1.itemID
            }
        }
    }

    /// Must be applied before LIMIT/OFFSET, using the same fallback as `ordered`.
    static let sqlOrderBy = "ORDER BY ZGROUPSORTORDER IS NULL, ZGROUPSORTORDER ASC, ZLASTUSEDAT DESC, ZITEMID ASC"

    static func resolve(_ itemIDs: [String], context: ModelContext) -> [ClipItem] {
        guard !itemIDs.isEmpty else { return [] }
        let descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { itemIDs.contains($0.itemID) })
        guard let items = try? context.fetch(descriptor) else { return [] }
        let byID = Dictionary(items.map { ($0.itemID, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        return itemIDs.compactMap { seen.insert($0).inserted ? byID[$0] : nil }
    }

    @discardableResult
    static func assign(_ items: [ClipItem], to name: String?, context: ModelContext) -> Bool {
        var seen = Set<String>()
        let validItems = items.filter { !$0.isDeleted && $0.modelContext === context && seen.insert($0.itemID).inserted }
        let changed = validItems.filter { $0.groupName != name }
        guard !changed.isEmpty else { return false }
        if let name {
            let descriptor = FetchDescriptor<SmartGroup>(predicate: #Predicate { $0.name == name })
            guard let group = try? context.fetch(descriptor).first,
                  let existing = try? groupItems(name, context: context) else { return false }
            // Freeze legacy members before appending. This avoids later pastes
            // unexpectedly moving items around a manually maintained group.
            let combined = ordered(existing) + changed
            for (index, item) in combined.enumerated() {
                item.groupName = name
                item.groupSortOrder = index
            }
            group.count = combined.count
        } else {
            for item in changed {
                item.groupName = nil
                item.groupSortOrder = nil
            }
        }
        recount(context)
        ClipItemStore.saveAndNotify(context)
        return true
    }

    /// Move a selection as one stable block before a target (nil means append).
    /// Items from another group may be moved here too, in a single save/notify.
    @discardableResult
    static func move(_ items: [ClipItem], in name: String, before itemID: String?, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<SmartGroup>(predicate: #Predicate { $0.name == name })
        guard (try? context.fetch(descriptor).first) != nil,
              let members = try? groupItems(name, context: context) else { return false }
        var seen = Set<String>()
        let moving = items.filter { !$0.isDeleted && $0.modelContext === context && seen.insert($0.itemID).inserted }
        guard !moving.isEmpty, itemID.map({ !seen.contains($0) }) ?? true else { return false }
        var remaining = ordered(members).filter { !seen.contains($0.itemID) }
        let insertion: Int
        if let itemID {
            guard let index = remaining.firstIndex(where: { $0.itemID == itemID }) else { return false }
            insertion = index
        } else {
            insertion = remaining.count
        }
        remaining.insert(contentsOf: moving, at: insertion)
        var changed = false
        for (index, item) in remaining.enumerated() {
            if item.groupName != name || item.groupSortOrder != index { changed = true }
            item.groupName = name
            item.groupSortOrder = index
        }
        guard changed else { return false }
        recount(context)
        ClipItemStore.saveAndNotify(context)
        return true
    }

    @discardableResult
    static func move(itemIDs: [String], in name: String, before itemID: String?, context: ModelContext) -> Bool {
        move(resolve(itemIDs, context: context), in: name, before: itemID, context: context)
    }

    /// Drop acceptance is synchronous; provider decoding returns on the main actor.
    static func handleDrop(providers: [NSItemProvider], to name: String?, before itemID: String? = nil, context: ModelContext) -> Bool {
        ClipItemDrag.load(providers) { ids in
            let items = resolve(ids, context: context)
            if let name, let itemID {
                move(items, in: name, before: itemID, context: context)
            } else {
                assign(items, to: name, context: context)
            }
        }
    }

    private static func groupItems(_ name: String, context: ModelContext) throws -> [ClipItem] {
        try context.fetch(FetchDescriptor<ClipItem>(predicate: #Predicate { $0.groupName == name }))
    }

    private static func recount(_ context: ModelContext) {
        guard let groups = try? context.fetch(FetchDescriptor<SmartGroup>()) else { return }
        for group in groups {
            let name = group.name
            let descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.groupName == name })
            if let count = try? context.fetchCount(descriptor) { group.count = count }
        }
    }
}

/// Local clip drags deliberately do not share the .text type used for tab reorder.
@MainActor
enum ClipItemDrag {
    static let type = UTType(exportedAs: "com.lifedever.pastememo.clip-items")
    static let pasteboardType = NSPasteboard.PasteboardType(type.identifier)
    private static let sessionID = UUID().uuidString

    private struct Payload: Codable {
        let sessionID: String
        let itemIDs: [String]
    }

    static func data(for items: [ClipItem]) -> Data? {
        try? JSONEncoder().encode(Payload(sessionID: sessionID, itemIDs: items.map(\.itemID)))
    }

    static func itemIDs(from data: Data) -> [String]? {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.sessionID == sessionID else { return nil }
        return payload.itemIDs
    }

    static func provider(for items: [ClipItem]) -> NSItemProvider {
        // Retain ordinary text export to other apps, while private metadata is
        // only used by our internal destinations. Sensitive clips stay private.
        let text = items.filter { !$0.isSensitive }.map(\.content).joined(separator: "\n")
        let provider = NSItemProvider(object: text as NSString)
        if let data = data(for: items) {
            provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .ownProcess) { completion in
                completion(data, nil)
                return nil
            }
        }
        return provider
    }

    @discardableResult
    static func load(_ providers: [NSItemProvider], completion: @escaping @MainActor ([String]) -> Void) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(type.identifier) }) else { return false }
        provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
            guard let data else { return }
            Task { @MainActor in
                guard let ids = itemIDs(from: data) else { return }
                completion(ids)
            }
        }
        return true
    }
}

enum SmartGroupPalette {
    static let names = ["blue", "purple", "pink", "red", "orange", "yellow", "green", "teal"]

    static func color(for name: String?) -> Color {
        switch name {
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "teal": return .teal
        default:
            if let name, let parsed = ColorConverter.parse(name) { return Color(nsColor: parsed.nsColor) }
            return .accentColor
        }
    }
}
