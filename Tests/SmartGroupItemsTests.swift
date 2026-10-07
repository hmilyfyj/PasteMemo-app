import AppKit
import Foundation
import SwiftData
import Testing
import UniformTypeIdentifiers
@testable import PasteMemo

@Suite("Reusable group membership and ordering")
@MainActor
struct SmartGroupItemsTests {
    private func container(url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([ClipItem.self, SmartGroup.self, AutomationRule.self])
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }

    private func fixtureDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PasteMemo-group-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("Assignment, moves, same-group no-op and removal maintain counts and retention")
    func membership() throws {
        let db = try container()
        let context = ModelContext(db)
        let work = SmartGroup(name: "Work", color: "purple", preservesItems: true)
        let personal = SmartGroup(name: "Personal", preservesItems: false)
        let a = ClipItem(content: "a")
        let b = ClipItem(content: "b")
        let c = ClipItem(content: "c")
        for group in [work, personal] { context.insert(group) }
        for item in [a, b, c] { context.insert(item) }
        try context.save()

        #expect(SmartGroupItems.assign([a, b, a], to: "Work", context: context))
        #expect(work.count == 2)
        #expect(SmartGroupItems.ordered([a, b]).map(\.content) == ["a", "b"])
        let oldRank = a.groupSortOrder
        #expect(!SmartGroupItems.assign([a], to: "Work", context: context))
        #expect(a.groupSortOrder == oldRank)
        #expect(work.count == 2)
        #expect(SmartGroupRetention.shouldPreserve(item: a, preservedGroupNames: SmartGroupRetention.preservedGroupNames(in: context)))

        #expect(SmartGroupItems.assign([a, c], to: "Personal", context: context))
        #expect(work.count == 1)
        #expect(personal.count == 2)
        #expect(!SmartGroupRetention.shouldPreserve(item: a, preservedGroupNames: SmartGroupRetention.preservedGroupNames(in: context)))
        #expect(work.preservesItems)
        #expect(SmartGroupItems.assign([a, c], to: nil, context: context))
        #expect(personal.count == 0)
        #expect(a.groupName == nil && a.groupSortOrder == nil)
        #expect(try context.fetchCount(FetchDescriptor<ClipItem>()) == 3)
        #expect(!SmartGroupItems.assign([a], to: "Missing", context: context))
        #expect(a.groupName == nil)
    }

    @Test("A multi-item move preserves relative order and supports the final position")
    func selectionMove() throws {
        let db = try container()
        let context = ModelContext(db)
        context.insert(SmartGroup(name: "Work"))
        let items = (0..<6).map { ClipItem(content: "\($0)") }
        for item in items { context.insert(item) }
        try context.save()
        SmartGroupItems.assign(items, to: "Work", context: context)
        #expect(SmartGroupItems.move([items[1], items[3]], in: "Work", before: items[5].itemID, context: context))
        #expect(SmartGroupItems.ordered(items).map(\.content) == ["0", "2", "4", "1", "3", "5"])
        #expect(SmartGroupItems.move([items[0], items[2]], in: "Work", before: nil, context: context))
        #expect(SmartGroupItems.ordered(items).map(\.content) == ["4", "1", "3", "5", "0", "2"])
        #expect(!SmartGroupItems.move([items[0], items[2]], in: "Work", before: items[0].itemID, context: context))
        #expect(!SmartGroupItems.move([items[0]], in: "Work", before: "missing", context: context))
        #expect(SmartGroupItems.resolve(["missing", items[3].itemID, items[3].itemID, items[0].itemID], context: context).map(\.content) == ["3", "0"])
    }

    @Test("Order persists on disk before SQL pagination and survives last-used updates and reopen")
    func diskPagination() throws {
        let directory = try fixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("History.store")
        let expected = ["64"] + (0..<64).map(String.init)
        try autoreleasepool {
            let db = try container(url: url)
            let context = ModelContext(db)
            context.insert(SmartGroup(name: "Work", color: "teal"))
            let date = Date()
            let items = (0..<65).map { ClipItem(content: "\($0)", lastUsedAt: date.addingTimeInterval(Double($0))) }
            for item in items { context.insert(item) }
            try context.save()
            SmartGroupItems.assign(items, to: "Work", context: context)
            SmartGroupItems.move([items[64]], in: "Work", before: items[0].itemID, context: context)
            // Paste updates this field; manual order must remain independent.
            items[20].lastUsedAt = date.addingTimeInterval(10_000)
            ClipItemStore.saveAndNotifyLastUsed(context)

            let store = ClipItemStore()
            store.groupName = "Work"
            store.sortPinnedFirst = true
            store.configure(modelContext: context)
            #expect(store.items.count == 50)
            #expect(store.items.map(\.content) == Array(expected.prefix(50)))
            #expect(store.hasMore)
            store.loadMore()
            #expect(store.items.map(\.content) == expected)
            #expect(!store.hasMore)
            #expect(store.sidebarCounts.byGroup.first?.count == 65)
            #expect(store.sidebarCounts.byGroup.first?.color == "teal")
            let latestHistory = ClipItem(content: "latest outside group", lastUsedAt: date.addingTimeInterval(20_000))
            context.insert(latestHistory)
            try context.save()
            #expect(store.groupName == "Work")
            #expect(store.queryFirstItemID() == latestHistory.itemID)
            #expect(store.items.map(\.content) == expected)
            store.groupName = nil
            store.sortPinnedFirst = false
            store.applyFilters()
            #expect(store.items.first?.content == "latest outside group")
            #expect(store.items.dropFirst().first?.content == "20")
        }

        let reopened = try container(url: url)
        let context = ModelContext(reopened)
        let store = ClipItemStore()
        store.groupName = "Work"
        store.configure(modelContext: context)
        #expect(store.items.map(\.content) == Array(expected.prefix(50)))
        store.loadMore()
        #expect(store.items.map(\.content) == expected)
        #expect(store.sidebarCounts.byGroup.first?.color == "teal")
    }

    @Test("Legacy unranked records keep deterministic chronology until reordered")
    func legacyFallback() throws {
        let directory = try fixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let db = try container(url: directory.appendingPathComponent("History.store"))
        let context = ModelContext(db)
        context.insert(SmartGroup(name: "Legacy"))
        let date = Date()
        let a = ClipItem(content: "older", lastUsedAt: date)
        let b = ClipItem(content: "newer", lastUsedAt: date.addingTimeInterval(1))
        for item in [a, b] { item.groupName = "Legacy"; context.insert(item) }
        try context.save()
        let store = ClipItemStore()
        store.groupName = "Legacy"
        store.configure(modelContext: context)
        #expect(store.items.map(\.content) == ["newer", "older"])
        #expect(SmartGroupItems.move([a], in: "Legacy", before: b.itemID, context: context))
        store.reload()
        #expect(store.items.map(\.content) == ["older", "newer"])
    }

    @Test("Deleting a group clears membership and ordering without deleting clips")
    func deleteGroup() throws {
        let db = try container()
        let context = ModelContext(db)
        context.insert(SmartGroup(name: "Work", preservesItems: true))
        let item = ClipItem(content: "keep")
        context.insert(item)
        try context.save()
        SmartGroupItems.assign([item], to: "Work", context: context)
        AppMenuActions.deleteGroup(name: "Work", context: context)
        #expect(item.groupName == nil && item.groupSortOrder == nil)
        #expect(try context.fetchCount(FetchDescriptor<ClipItem>()) == 1)
    }

    @Test("Automation moves clear old ranks and same-group actions keep counts and order")
    func automationMembership() throws {
        let db = try container()
        let context = ModelContext(db)
        let work = SmartGroup(name: "Work")
        let personal = SmartGroup(name: "Personal")
        for group in [work, personal] { context.insert(group) }
        let item = ClipItem(content: "move")
        context.insert(item)
        try context.save()
        SmartGroupItems.assign([item], to: "Work", context: context)
        let rank = item.groupSortOrder
        ActionExecutor.applyMetadata([.assignGroup(name: "Work")], to: [item], context: context)
        #expect(work.count == 1 && personal.count == 0 && item.groupSortOrder == rank)
        ActionExecutor.applyMetadata([.assignGroup(name: "Personal")], to: [item], context: context)
        #expect(work.count == 0 && personal.count == 1)
        #expect(item.groupName == "Personal" && item.groupSortOrder == nil)
        ActionExecutor.applyMetadata([.assignGroup(name: "Personal")], to: [item], context: context)
        #expect(personal.count == 1)
    }

    @Test("Duplicate capture keeps established ordering and inherits incoming membership rank")
    func duplicateMembership() throws {
        let db = try container()
        let context = ModelContext(db)
        let group = SmartGroup(name: "Work")
        context.insert(group)
        let existing = ClipItem(content: "same")
        context.insert(existing)
        try context.save()
        let incoming = ClipItem(content: "same")
        incoming.groupName = "Work"
        incoming.groupSortOrder = 7
        ClipboardManager.shared.reuseExistingDuplicate(existing, with: incoming, in: context)
        try context.save()
        #expect(existing.groupName == "Work" && existing.groupSortOrder == 7)
        #expect(group.count == 1)
        incoming.groupSortOrder = 0
        ClipboardManager.shared.reuseExistingDuplicate(existing, with: incoming, in: context)
        #expect(existing.groupSortOrder == 7 && group.count == 1)
    }

    @Test("Deletion snapshot restores an item's manual place after timestamp changes")
    func undoOrder() throws {
        let db = try container()
        let context = ModelContext(db)
        context.insert(SmartGroup(name: "Work"))
        let items = (0..<3).map { ClipItem(content: "\($0)") }
        for item in items { context.insert(item) }
        try context.save()
        SmartGroupItems.assign(items, to: "Work", context: context)
        items[1].lastUsedAt = Date().addingTimeInterval(100)
        let snapshot = ClipItemSnapshot(from: items[1])
        context.delete(items[1])
        try context.save()
        snapshot.restore(into: context)
        try context.save()
        let restored = try context.fetch(FetchDescriptor<ClipItem>())
        #expect(SmartGroupItems.ordered(restored).map(\.content) == ["0", "1", "2"])
        #expect(restored.first(where: { $0.content == "1" })?.itemID == snapshot.itemID)
    }

    @Test("Export, streaming backup restore and old v1/v2 imports preserve optional order")
    func exportCompatibility() async throws {
        let source = try container()
        let context = ModelContext(source)
        let group = SmartGroup(name: "Work", color: "pink", preservesItems: true)
        context.insert(group)
        let a = ClipItem(content: "a")
        let b = ClipItem(content: "b")
        for item in [a, b] { context.insert(item) }
        try context.save()
        SmartGroupItems.assign([b, a], to: "Work", context: context)
        let payload = DataPorter.buildExportPayload([a, b], groups: [group], rules: [])
        let exported = try DataPorter.encodeAndCompress(payload)
        let destination = try container()
        let destinationContext = ModelContext(destination)
        let result = try DataPorter.importItems(from: exported, into: destinationContext)
        #expect(result.imported == 2)
        #expect(SmartGroupItems.ordered(try destinationContext.fetch(FetchDescriptor<ClipItem>())).map(\.content) == ["b", "a"])

        let directory = try fixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let streamURL = directory.appendingPathComponent("backup.zlib")
        try await DataPorter.encodeAndCompress(clipItems: [a, b], groups: [group], rules: [], to: streamURL)
        let backup = FixtureGroupBackup(data: DataPorterCrypto.wrapPlaintext(try Data(contentsOf: streamURL)))
        let restored = try container()
        let metadata = BackupMetadata(fileName: "fixture.pastememo", slot: 1, createdAt: Date(), itemCount: 2, fileSize: 0)
        let restore = try await BackupEngine.restore(from: metadata, destination: backup, strategy: .overwrite, container: restored)
        #expect(restore.restoredCount == 2)
        let restoredContext = ModelContext(restored)
        #expect(SmartGroupItems.ordered(try restoredContext.fetch(FetchDescriptor<ClipItem>())).map(\.content) == ["b", "a"])
        let restoredGroup = try #require(restoredContext.fetch(FetchDescriptor<SmartGroup>()).first)
        #expect(restoredGroup.color == "pink" && restoredGroup.preservesItems && restoredGroup.count == 2)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var json = try #require(JSONSerialization.jsonObject(with: encoder.encode(payload)) as? [String: Any])
        let legacyItems = try #require(json["items"] as? [[String: Any]]).map { row in
            var row = row
            row.removeValue(forKey: "groupSortOrder")
            return row
        }
        json["items"] = legacyItems
        for version in [1, 2] {
            json["version"] = version
            let oldData = try JSONSerialization.data(withJSONObject: json)
            let legacy = try container()
            let legacyContext = ModelContext(legacy)
            #expect(try DataPorter.importItems(from: oldData, into: legacyContext).imported == 2)
            #expect(try legacyContext.fetch(FetchDescriptor<ClipItem>()).allSatisfy { $0.groupSortOrder == nil })
        }
    }

    @Test("Only a local private payload can assign clips; sensitive drag text stays absent")
    func dragPayload() async throws {
        let a = ClipItem(content: "visible")
        let secret = ClipItem(content: "secret")
        secret.isSensitive = true
        let data = try #require(ClipItemDrag.data(for: [a, secret]))
        #expect(ClipItemDrag.itemIDs(from: data) == [a.itemID, secret.itemID])
        #expect(ClipItemDrag.itemIDs(from: Data("ordinary text".utf8)) == nil)
        #expect(!ClipItemDrag.type.conforms(to: .text))
        var payload = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        payload["sessionID"] = "another-process"
        #expect(ClipItemDrag.itemIDs(from: try JSONSerialization.data(withJSONObject: payload)) == nil)
        let provider = ClipItemDrag.provider(for: [a, secret])
        let text: String? = await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.utf8PlainText.identifier) { data, _ in
                continuation.resume(returning: data.flatMap { String(data: $0, encoding: .utf8) })
            }
        }
        #expect(text == "visible")
    }
}

private struct FixtureGroupBackup: BackupDestination {
    let data: Data
    var displayName: String { "Isolated group fixture" }
    var isAvailable: Bool { get async { true } }
    func upload(data: Data, fileName: String) async throws {}
    func download(fileName: String) async throws -> Data { data }
    func list() async throws -> [BackupMetadata] { [] }
    func delete(fileName: String) async throws {}
}
