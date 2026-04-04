import AppKit
import Foundation

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var latestVersion: String?
    @Published var updateAvailable = false
    @Published var releaseNotes: String?
    @Published var downloadURL: URL?
    @Published var isChecking = false

    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var downloadedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var downloadComplete = false
    @Published var downloadedFileURL: URL?

    @Published var showUpdateDialog = false

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private init() {}

    func checkForUpdates(userInitiated: Bool = false) async {
        isChecking = true
        defer { isChecking = false }

        latestVersion = nil
        updateAvailable = false
        releaseNotes = nil
        downloadURL = nil
        downloadComplete = false
        downloadedFileURL = nil
        downloadProgress = 0
        downloadedBytes = 0
        totalBytes = 0

        guard userInitiated else { return }
        showDisabledAlert()
    }

    func downloadUpdate() {
        showDisabledAlert()
    }

    func cancelDownload() {
        isDownloading = false
        downloadProgress = 0
        downloadComplete = false
        downloadedFileURL = nil
    }

    func skipVersion(_ version: String) {
        showUpdateDialog = false
    }

    func installAndRestart() {
        showDisabledAlert()
    }

    func startPeriodicChecks() {}

    private func showDisabledAlert() {
        let alert = NSAlert()
        alert.messageText = localizedString(
            zh: "更新检查已禁用",
            en: "Update Checks Disabled"
        )
        alert.informativeText = localizedString(
            zh: "这个构建已移除外部更新服务，不会连接远程服务器检查、下载或安装更新。",
            en: "This build has external update services disabled and will not contact remote servers to check, download, or install updates."
        )
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.tr("action.confirm"))
        alert.runModal()
    }

    private func localizedString(zh: String, en: String) -> String {
        let lang = LanguageManager.shared.current.lowercased()
        return lang.hasPrefix("zh") ? zh : en
    }
}
