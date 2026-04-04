import SwiftUI
import AppKit

struct AppMenuItemDefinition: Identifiable {
    let id: String
    let title: String
    let trailingText: String?
    let isEnabled: Bool
    let isDestructive: Bool
    let action: () -> Void
}

struct AppMenuSectionDefinition: Identifiable {
    let id: String
    let items: [AppMenuItemDefinition]
}

@MainActor
enum AppMenuFactory {
    static func makeSections(
        hotkeyManager: HotkeyManager,
        clipboardManager: ClipboardManager,
        onOpenManager: @escaping () -> Void,
        onOpenQuickPanel: @escaping () -> Void,
        onOpenAutomationManager: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) -> [AppMenuSectionDefinition] {
        let managerShortcut = hotkeyManager.isManagerCleared
            ? nil
            : shortcutDisplayString(keyCode: hotkeyManager.managerKeyCode, modifiers: hotkeyManager.managerModifiers)
        let quickPanelShortcut = hotkeyManager.displayString.isEmpty ? nil : hotkeyManager.displayString
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "PasteMemo"

        return [
            AppMenuSectionDefinition(
                id: "primary",
                items: [
                    AppMenuItemDefinition(
                        id: "manager",
                        title: L10n.tr("menu.manager"),
                        trailingText: managerShortcut,
                        isEnabled: true,
                        isDestructive: false,
                        action: onOpenManager
                    ),
                    AppMenuItemDefinition(
                        id: "quickPanel",
                        title: L10n.tr("menu.quickPanel"),
                        trailingText: quickPanelShortcut,
                        isEnabled: true,
                        isDestructive: false,
                        action: onOpenQuickPanel
                    ),
                    AppMenuItemDefinition(
                        id: "pause",
                        title: clipboardManager.isPaused ? L10n.tr("menu.resume") : L10n.tr("menu.pause"),
                        trailingText: nil,
                        isEnabled: !RelayManager.shared.isActive,
                        isDestructive: false,
                        action: {
                            clipboardManager.togglePause()
                        }
                    ),
                    AppMenuItemDefinition(
                        id: "relay",
                        title: RelayManager.shared.isActive
                            ? "\(L10n.tr("relay.title")) (\(RelayManager.shared.progressText)) — \(L10n.tr("relay.exitRelay"))"
                            : L10n.tr("relay.startRelay"),
                        trailingText: nil,
                        isEnabled: true,
                        isDestructive: false,
                        action: {
                            if RelayManager.shared.isActive {
                                RelayManager.shared.deactivate()
                            } else {
                                RelayManager.shared.activate()
                            }
                        }
                    ),
                ]
            ),
            AppMenuSectionDefinition(
                id: "secondary",
                items: [
                    AppMenuItemDefinition(
                        id: "automation",
                        title: L10n.tr("settings.automation.manage"),
                        trailingText: nil,
                        isEnabled: true,
                        isDestructive: false,
                        action: onOpenAutomationManager
                    ),
                    AppMenuItemDefinition(
                        id: "settings",
                        title: L10n.tr("menu.settings"),
                        trailingText: nil,
                        isEnabled: true,
                        isDestructive: false,
                        action: onOpenSettings
                    ),
                ]
            ),
            AppMenuSectionDefinition(
                id: "danger",
                items: [
                    AppMenuItemDefinition(
                        id: "quit",
                        title: L10n.tr("menu.quit", appName),
                        trailingText: nil,
                        isEnabled: true,
                        isDestructive: true,
                        action: {
                            AppDelegate.shouldReallyQuit = true
                            NSApp.terminate(nil)
                        }
                    ),
                ]
            ),
        ]
    }
}

struct QuickPanelOverflowMenu: View {
    let sections: [AppMenuSectionDefinition]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                VStack(spacing: 4) {
                    ForEach(section.items) { item in
                        QuickPanelOverflowMenuRow(item: item)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)

                if index < sections.count - 1 {
                    Divider()
                        .overlay(Color.white.opacity(0.08))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
            }
        }
        .padding(.vertical, 6)
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.13, blue: 0.10).opacity(0.98),
                            Color(red: 0.10, green: 0.11, blue: 0.09).opacity(0.99),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.36), radius: 24, y: 14)
    }
}

private struct QuickPanelOverflowMenuRow: View {
    let item: AppMenuItemDefinition
    @State private var isHovering = false

    var body: some View {
        Button {
            item.action()
        } label: {
            HStack(spacing: 12) {
                Text(item.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(item.isDestructive ? Color.white.opacity(0.92) : Color.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let trailingText = item.trailingText, !trailingText.isEmpty {
                    Text(trailingText)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHovering && item.isEnabled ? QuickPanelBottomTheme.selectionBlue : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(!item.isEnabled)
        .opacity(item.isEnabled ? 1 : 0.46)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
