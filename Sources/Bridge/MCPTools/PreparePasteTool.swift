import Foundation
import SwiftData

@MainActor
struct PreparePasteTool: MCPTool {
    struct Output: Codable {
        let written: Bool
        let item_id: String
    }

    static var descriptor: MCPToolDescriptor {
        MCPToolDescriptor(
            name: "clipboard_select_item",
            description: "Load an existing clipboard history item onto the system pasteboard "
                + "so the user can paste it with Cmd+V. Unlike clipboard_set, this reuses "
                + "PasteMemo's internal paste writer and self-write marker, so it does not "
                + "create a duplicate history entry or reorder existing items.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "id": .object(["type": .string("string")])
                ]),
                "required": .array([.string("id")])
            ])
        )
    }

    func call(
        params: JSONValue?,
        container: ModelContainer,
        guardLayer: PrivacyGuard,
        clientName: String? = nil
    ) async throws -> JSONValue {
        guard let id = params?.objectValue?["id"]?.stringValue else {
            throw MCPToolError.invalidParams("missing 'id'")
        }

        let context = container.mainContext
        // 按 itemID 走 idx_clip_itemid 索引取单条。原先全表 fetch 再线性查找，万条级库
        // 每次调用都在主线程物化整张表（含缩略图 blob），卡数百毫秒。
        var descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.itemID == id })
        descriptor.fetchLimit = 1
        guard let item = try context.fetch(descriptor).first else {
            throw MCPToolError.toolError("Item not found: \(id)")
        }
        guard guardLayer.filter([item]).first != nil else {
            throw MCPToolError.toolError("Item not found: \(id)")
        }

        ClipboardManager.shared.writeToPasteboard(item)
        return try MCPToolResult.textJSON(Output(written: true, item_id: item.itemID))
    }
}
