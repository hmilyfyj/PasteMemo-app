import AppKit
import SwiftUI

// MARK: - Bridge for SwiftUI → AppKit window actions

@MainActor
final class AppAction {
    static let shared = AppAction()
    var openMainWindow: (() -> Void)?
    var openSettings: (() -> Void)?
    var openAutomationManager: (() -> Void)?
    private init() {}
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shouldReallyQuit = false
    private var isLaunchComplete = false

    override init() {
        super.init()
        NSApp?.setActivationPolicy(.accessory)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        LaunchPerformanceMonitor.shared.startMonitoring()
        
        LaunchPerformanceMonitor.shared.beginStage("Appearance Setup")
        let mode = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
        AppDelegate.applyAppearance(mode)
        LaunchPerformanceMonitor.shared.endStage("Appearance Setup")
        
        LaunchPerformanceMonitor.shared.beginStage("Core Initialization")
        ClipboardManager.shared.modelContainer = PasteMemoApp.sharedModelContainer
        OCRTaskCoordinator.shared.configure(modelContainer: PasteMemoApp.sharedModelContainer)
        LaunchPerformanceMonitor.shared.endStage("Core Initialization")
        
        LaunchPerformanceMonitor.shared.beginStage("Automation Rules")
        if ProManager.AUTOMATION_ENABLED {
            BuiltInRules.seedIfNeeded(context: PasteMemoApp.sharedModelContainer.mainContext)
        }
        LaunchPerformanceMonitor.shared.endStage("Automation Rules")
        
        LaunchPerformanceMonitor.shared.beginStage("Clipboard Monitoring")
        ClipboardManager.shared.startMonitoring()
        LaunchPerformanceMonitor.shared.endStage("Clipboard Monitoring")
        
        hideAllMainWindows(NSApp)
        isLaunchComplete = true
        
        LaunchPerformanceMonitor.shared.beginStage("Hotkey Registration")
        HotkeyManager.shared.register()
        LaunchPerformanceMonitor.shared.endStage("Hotkey Registration")
        
        RelayManager.shared.clipboardController = ClipboardManager.shared
        RelayManager.shared.hotkeyController = HotkeyManager.shared
        
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let needsAccessibility = !AXIsProcessTrusted()
        
        if !hasCompletedOnboarding || needsAccessibility {
            let hideDock = UserDefaults.standard.bool(forKey: "hideDockIcon")
            if !hideDock {
                NSApp.setActivationPolicy(.regular)
            }
            showOnboardingWindow()
        }
        
        LaunchPerformanceMonitor.shared.beginStage("Deferred Initialization")
        Task { @MainActor in
            await self.performDeferredInitialization()
        }
        
        LaunchPerformanceMonitor.shared.endMonitoring()
    }
    
    private func performDeferredInitialization() async {
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        LaunchPerformanceMonitor.shared.beginStage("Update Check")
        await UpdateChecker.shared.checkForUpdates()
        UpdateChecker.shared.startPeriodicChecks()
        LaunchPerformanceMonitor.shared.endStage("Update Check")
        
        LaunchPerformanceMonitor.shared.beginStage("Backup Scheduler")
        BackupScheduler.shared.start(container: PasteMemoApp.sharedModelContainer)
        LaunchPerformanceMonitor.shared.endStage("Backup Scheduler")
        
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        LaunchPerformanceMonitor.shared.beginStage("Quick Panel Warmup")
        QuickPanelWindowController.shared.warmUp(
            clipboardManager: ClipboardManager.shared,
            modelContainer: PasteMemoApp.sharedModelContainer
        )
        LaunchPerformanceMonitor.shared.endStage("Quick Panel Warmup")
        
        LaunchPerformanceMonitor.shared.beginStage("Highlight Engine Warmup")
        _ = HighlightEngine.shared
        LaunchPerformanceMonitor.shared.endStage("Highlight Engine Warmup")
    }

    func applicationWillTerminate(_ notification: Notification) {
        BackupScheduler.shared.stop()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard AppDelegate.shouldReallyQuit else {
            hideAllMainWindows(sender)
            NSApp.setActivationPolicy(.accessory)
            return .terminateCancel
        }
        return .terminateNow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        AppAction.shared.openMainWindow?()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        if isLaunchComplete {
            NSApp.setActivationPolicy(.accessory)
        }
        return false
    }

    // MARK: - Helpers

    private func hideAllMainWindows(_ sender: NSApplication) {
        for window in sender.windows where window.isVisible && window.canBecomeMain {
            window.close()
        }
    }

    static func applyAppearance(_ mode: String) {
        switch mode {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }

}
