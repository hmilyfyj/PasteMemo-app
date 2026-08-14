import AppKit
import ApplicationServices
import Combine
import Foundation
import PermissionFlow

@MainActor
final class AccessibilityMonitor: ObservableObject {
    static let shared = AccessibilityMonitor()

    @Published private(set) var isTrusted: Bool = AXIsProcessTrusted()

    private var timer: Timer?
    private let permissionController = PermissionFlow.makeController(
        configuration: .init(
            requiredAppURLs: [Bundle.main.bundleURL],
            promptForAccessibilityTrust: false
        )
    )

    private init() {
        startPolling()
    }

    private func startPolling() {
        // Poll every 2 seconds. Lightweight API call; cheaper than wiring
        // into the private AXAPI notification channel.
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let current = AXIsProcessTrusted()
                if current != self.isTrusted {
                    self.isTrusted = current
                }
            }
        }
    }

    func openAccessibilitySettings(sourceFrameInScreen: CGRect? = nil) {
        // Pre-1.6 → 1.6.x users may have arrived here without PermissionFlow's
        // resource bundle (the buggy in-app updater never copied it). Touching
        // the floating panel below would SIGTRAP at `Bundle.module` (issue #38).
        // Detect the missing bundle and degrade to a guided-reinstall alert,
        // keeping every entry point (menu bar, onboarding, alert) safe.
        guard Self.permissionFlowBundleAvailable() else {
            Self.showReinstallRequiredAlert()
            return
        }
        let frame = sourceFrameInScreen ?? defaultSourceFrame()
        permissionController.authorize(
            pane: .accessibility,
            suggestedAppURLs: [Bundle.main.bundleURL],
            sourceFrameInScreen: frame,
            panelHint: L10n.tr("accessibility.panelHint"),
            panelTitle: L10n.tr("accessibility.panelTitle")
        )
    }

    private func defaultSourceFrame() -> CGRect {
        let location = NSEvent.mouseLocation
        return CGRect(x: location.x - 16, y: location.y - 16, width: 32, height: 32)
    }

    private static func permissionFlowBundleAvailable() -> Bool {
        // Mirror PermissionFlow's own resolver: signed builds keep the bundle
        // in Contents/Resources, legacy ad-hoc builds at the .app root.
        // Checking only the root made every signed build show the
        // "reinstall required" alert (v1.7.15-beta.1 false positive).
        let name = "PermissionFlow_PermissionFlow.bundle"
        let candidates: [URL?] = [Bundle.main.resourceURL, Bundle.main.bundleURL]
        return candidates.contains { candidate in
            guard let url = candidate?.appendingPathComponent(name) else { return false }
            return FileManager.default.fileExists(atPath: url.path)
        }
    }

    private static func showReinstallRequiredAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.tr("reinstall.required.title")
        alert.informativeText = L10n.tr("reinstall.required.message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.tr("reinstall.required.action"))
        alert.addButton(withTitle: L10n.tr("accessibility.lost.later"))

        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "https://www.lifedever.com/PasteMemo/download") {
            NSWorkspace.shared.open(url)
        }
    }
}
