import Foundation
import SwiftData

@MainActor
struct ShowQuickPanelTool: MCPTool {
    struct Output: Codable {
        let opened: Bool
    }

    static var descriptor: MCPToolDescriptor {
        MCPToolDescriptor(
            name: "ui_show_quick_panel",
            description: "Open the Quick Paste panel so the user can browse and paste from clipboard history. Use when the user asks to see their clipboard history or open the quick paste menu.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:])
            ])
        )
    }

    func call(
        params: JSONValue?,
        container: ModelContainer,
        guardLayer: PrivacyGuard,
        clientName: String? = nil
    ) async throws -> JSONValue {
        DiagnosticLog.log("INVOKE ui_show_quick_panel MCP tool")
        HotkeyManager.shared.showQuickPanel()
        return try MCPToolResult.textJSON(Output(opened: true))
    }
}