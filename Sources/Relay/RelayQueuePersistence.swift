import Foundation

struct PersistedRelayQueue: Codable {
    let items: [PersistedRelayItem]
    let currentIndex: Int
    let savedAt: Date
}

struct PersistedRelayItem: Codable {
    let id: UUID
    let content: String
    let imageData: Data?
    /// Raw value of RelayItem.ContentKind: "text" / "image" / "file"
    let contentKind: String?
    /// Full pasteboard snapshot (binary plist of [String: Data]).
    let pasteboardSnapshot: Data?
    /// Raw value of RelayItem.ItemState: "pending" / "current" / "done" / "skipped".
    let state: String
    /// Bundle identifier of the app the clip originated from. Optional for backward
    /// compatibility with queues persisted before this field existed — default lets
    /// callers that don't know the source (e.g. old tests, split-item paths) omit it.
    var sourceAppBundleID: String? = nil
}

@MainActor
enum RelayQueuePersistence {

    private static var fileURL: URL? {
        guard let dir = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        let pasteMemoDir = dir.appendingPathComponent("PasteMemo", isDirectory: true)
        try? FileManager.default.createDirectory(at: pasteMemoDir, withIntermediateDirectories: true)
        return pasteMemoDir.appendingPathComponent("relay-queue.json")
    }

    static func save(_ items: [PersistedRelayItem], currentIndex: Int) {
        guard let url = fileURL else { return }
        if items.isEmpty {
            delete()
            return
        }
        let queue = PersistedRelayQueue(items: items, currentIndex: currentIndex, savedAt: Date())
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(queue)
            try data.write(to: url, options: .atomic)
        } catch {
            // Non-fatal: persistence best-effort
            print("RelayQueuePersistence save failed: \(error)")
        }
    }

    static func load() -> PersistedRelayQueue? {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(PersistedRelayQueue.self, from: data)
        } catch {
            // Corrupt file: remove it and start fresh
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    static func delete() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
