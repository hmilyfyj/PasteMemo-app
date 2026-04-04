import Foundation
import SwiftData
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct PasteAppMigrationResult {
    let imported: Int
    let skipped: Int
    let errors: [String]
}

enum PasteAppMigrator {
    static let pasteAppDBPath = "~/Library/Containers/com.wiheads.paste/Data/Library/Application Support/Paste/db.sqlite"
    static let pasteAppExternalDataPath = "~/Library/Containers/com.wiheads.paste/Data/Library/Application Support/Paste/.db_SUPPORT/_EXTERNAL_DATA"

    static func checkPasteAppDatabaseExists() -> Bool {
        let path = (pasteAppDBPath as NSString).expandingTildeInPath
        return FileManager.default.fileExists(atPath: path)
    }

    static func getPasteAppItemCount() -> Int {
        let path = (pasteAppDBPath as NSString).expandingTildeInPath
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return 0
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM ZITEMENTITY", -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    @MainActor
    static func migrate(
        into context: ModelContext,
        progress: @escaping (Int, Int, String) -> Void
    ) async -> PasteAppMigrationResult {
        let dbPath = (pasteAppDBPath as NSString).expandingTildeInPath
        let externalDataPath = (pasteAppExternalDataPath as NSString).expandingTildeInPath

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return PasteAppMigrationResult(imported: 0, skipped: 0, errors: ["Failed to open Paste.app database"])
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let query = """
            SELECT Z_PK, ZRAWTYPE, ZTITLE, ZRAWPREVIEW, ZCREATEDAT, ZTIMESTAMP, ZIDENTIFIER
            FROM ZITEMENTITY
            ORDER BY ZCREATEDAT DESC
            """
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return PasteAppMigrationResult(imported: 0, skipped: 0, errors: ["Failed to prepare query"])
        }

        var items: [(pk: Int, rawType: Int, title: String?, preview: String?, createdAt: Double?, timestamp: Double?, identifier: String?)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let pk = Int(sqlite3_column_int64(stmt, 0))
            let rawType = Int(sqlite3_column_int64(stmt, 1))
            let title = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
            let preview = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let createdAt = sqlite3_column_double(stmt, 4)
            let timestamp = sqlite3_column_double(stmt, 5)
            let identifier = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
            items.append((pk, rawType, title, preview, createdAt, timestamp, identifier))
        }
        sqlite3_finalize(stmt)

        let total = items.count
        var imported = 0
        var skipped = 0
        var errors: [String] = []

        for (index, item) in items.enumerated() {
            let typeStr = rawTypeToString(item.rawType)
            progress(index + 1, total, "Migrating \(typeStr) item...")

            if let error = await migrateItem(
                item: item,
                context: context,
                externalDataPath: externalDataPath
            ) {
                if error == "duplicate" {
                    skipped += 1
                } else {
                    errors.append("Item \(item.pk): \(error)")
                    skipped += 1
                }
            } else {
                imported += 1
            }

            if (index + 1) % 100 == 0 {
                try? context.save()
                await Task.yield()
            }
        }

        try? context.save()
        return PasteAppMigrationResult(imported: imported, skipped: skipped, errors: errors)
    }

    @MainActor
    private static func migrateItem(
        item: (pk: Int, rawType: Int, title: String?, preview: String?, createdAt: Double?, timestamp: Double?, identifier: String?),
        context: ModelContext,
        externalDataPath: String
    ) async -> String? {
        guard let preview = item.preview,
              let previewData = preview.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: previewData) as? [String: Any] else {
            return "Invalid preview JSON"
        }

        let contentType = rawTypeToContentType(item.rawType)
        let content: String
        var imageData: Data? = nil
        var linkTitle: String? = nil

        switch item.rawType {
        case 5:
            guard let text = json["text"] as? String else { return "Missing text content" }
            content = text
        case 4:
            guard let url = json["url"] as? String else { return "Missing URL" }
            content = url
            linkTitle = json["urlName"] as? String ?? item.title
        case 1:
            content = "[Image]"
            if let base64Data = json["imageData"] as? String,
               let data = Data(base64Encoded: base64Data) {
                imageData = data
            } else if let imageName = json["imageName"] as? String {
                let imagePath = URL(fileURLWithPath: externalDataPath).appendingPathComponent(imageName)
                if let data = try? Data(contentsOf: imagePath) {
                    imageData = data
                }
            }
        case 3:
            if let filePaths = json["filePaths"] as? [String] {
                content = filePaths.joined(separator: "\n")
            } else {
                content = item.title ?? "[Files]"
            }
        case 2:
            guard let color = json["color"] as? String else { return "Missing color" }
            content = color
        default:
            content = item.title ?? "[Unknown]"
        }

        let createdAtDate = coreDataTimestampToDate(item.createdAt ?? item.timestamp)
        let lastUsedAtDate = coreDataTimestampToDate(item.timestamp ?? item.createdAt)

        if isDuplicate(content: content, createdAt: createdAtDate, in: context) {
            return "duplicate"
        }

        let clip = ClipItem(
            content: content,
            contentType: contentType,
            imageData: imageData,
            sourceApp: nil,
            createdAt: createdAtDate,
            lastUsedAt: lastUsedAtDate
        )
        clip.linkTitle = linkTitle

        context.insert(clip)
        return nil
    }

    private static func rawTypeToString(_ type: Int) -> String {
        switch type {
        case 1: return "image"
        case 2: return "color"
        case 3: return "files"
        case 4: return "link"
        case 5: return "text"
        default: return "unknown"
        }
    }

    private static func rawTypeToContentType(_ type: Int) -> ClipContentType {
        switch type {
        case 1: return .image
        case 2: return .color
        case 3: return .file
        case 4: return .link
        case 5: return .text
        default: return .text
        }
    }

    private static func coreDataTimestampToDate(_ timestamp: Double?) -> Date {
        guard let ts = timestamp else { return Date() }
        let referenceDate = Date(timeIntervalSinceReferenceDate: 0)
        return referenceDate.addingTimeInterval(ts)
    }

    @MainActor
    private static func isDuplicate(content: String, createdAt: Date, in context: ModelContext) -> Bool {
        let lowerBound = createdAt.addingTimeInterval(-1)
        let upperBound = createdAt.addingTimeInterval(1)

        let descriptor = FetchDescriptor<ClipItem>(
            predicate: #Predicate<ClipItem> {
                $0.content == content
                    && $0.createdAt >= lowerBound
                    && $0.createdAt <= upperBound
            }
        )
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count > 0
    }
}
