import SwiftUI

struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    @AppStorage("hideDockIcon") private var hideDockIcon = false

    var body: some View {
        let _ = storeOpenWindowAction()
        let sections = AppMenuFactory.makeSections(
            hotkeyManager: hotkeyManager,
            clipboardManager: clipboardManager,
            onOpenManager: handleOpenMainWindow,
            onOpenQuickPanel: handleOpenQuickPanel,
            onOpenAutomationManager: {
                AppAction.shared.openAutomationManager?()
            },
            onOpenSettings: {
                if !hideDockIcon {
                    NSApp.setActivationPolicy(.regular)
                }
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
        )

        ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
            ForEach(section.items) { item in
                Button {
                    item.action()
                } label: {
                    HStack(spacing: 12) {
                        Text(item.title)
                        Spacer(minLength: 12)
                        if let trailingText = item.trailingText, !trailingText.isEmpty {
                            Text(trailingText)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(!item.isEnabled)
            }

            if index < sections.count - 1 {
                Divider()
            }
        }
    }

    private func storeOpenWindowAction() {
        let hideDock = hideDockIcon
        AppAction.shared.openMainWindow = { [openWindow] in
            openWindow(id: "main")
            if !hideDock {
                NSApp.setActivationPolicy(.regular)
            }
            NSApp.activate(ignoringOtherApps: true)
        }
        AppAction.shared.openSettings = { [openSettings] in
            if !hideDock {
                NSApp.setActivationPolicy(.regular)
            }
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        AppAction.shared.openAutomationManager = { [openWindow] in
            if !hideDock {
                NSApp.setActivationPolicy(.regular)
            }
            openWindow(id: "automationManager")
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func handleOpenMainWindow() {
        openWindow(id: "main")
        if !hideDockIcon {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func handleOpenQuickPanel() {
        print("🎯 [MenuBarView] handleOpenQuickPanel() called")
        QuickPanelWindowController.shared.show(
            clipboardManager: ClipboardManager.shared,
            modelContainer: PasteMemoApp.sharedModelContainer
        )
    }
}
