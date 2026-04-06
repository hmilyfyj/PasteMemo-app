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

    private let githubOwner = "hmilyfyj"
    private let githubRepo = "PasteMemo-app"
    private var downloadTask: Task<Void, Never>?
    private var periodicCheckTask: Task<Void, Never>?

    private var cachedETag: String? {
        get { UserDefaults.standard.string(forKey: "updateChecker.cachedETag") }
        set { UserDefaults.standard.set(newValue, forKey: "updateChecker.cachedETag") }
    }

    private var cachedRelease: GitHubRelease? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "updateChecker.cachedRelease") else { return nil }
            return try? JSONDecoder().decode(GitHubRelease.self, from: data)
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "updateChecker.cachedRelease")
            } else {
                UserDefaults.standard.removeObject(forKey: "updateChecker.cachedRelease")
            }
        }
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private init() {}

    func checkForUpdates(userInitiated: Bool = false) async {
        isChecking = true
        defer { isChecking = false }

        if userInitiated {
            cachedETag = nil
            cachedRelease = nil
            print("[UpdateChecker] Cleared cache for user-initiated check")
        }

        latestVersion = nil
        updateAvailable = false
        releaseNotes = nil
        downloadURL = nil
        downloadComplete = false
        downloadedFileURL = nil
        downloadProgress = 0
        downloadedBytes = 0
        totalBytes = 0

        let apiURL = "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest"
        print("[UpdateChecker] Checking for updates: \(apiURL)")

        guard let url = URL(string: apiURL) else {
            if userInitiated {
                showErrorAlert(message: localizedString(
                    zh: "无效的 API URL",
                    en: "Invalid API URL"
                ))
            }
            return
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            request.timeoutInterval = 30

            if let etag = cachedETag {
                print("[UpdateChecker] Using ETag: \(etag)")
                request.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw UpdateError.invalidResponse
            }

            print("[UpdateChecker] Response status: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                print("[UpdateChecker] Got release: \(release.tagName)")
                if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
                    cachedETag = etag
                    cachedRelease = release
                }
                await handleRelease(release, userInitiated: userInitiated)
            case 304:
                print("[UpdateChecker] Not modified, using cache")
                if let cached = cachedRelease {
                    await handleRelease(cached, userInitiated: userInitiated)
                } else {
                    print("[UpdateChecker] No cache, retrying without ETag")
                    cachedETag = nil
                    await checkForUpdates(userInitiated: userInitiated)
                }
            case 403:
                print("[UpdateChecker] Rate limited")
                if let cached = cachedRelease {
                    print("[UpdateChecker] Using cached release")
                    await handleRelease(cached, userInitiated: userInitiated)
                } else {
                    throw UpdateError.rateLimited
                }
            case 404:
                throw UpdateError.noReleases
            default:
                throw UpdateError.httpError(statusCode: httpResponse.statusCode)
            }
        } catch {
            print("[UpdateChecker] Error: \(error)")
            if userInitiated {
                showErrorAlert(message: localizedString(
                    zh: "检查更新失败: \(error.localizedDescription)",
                    en: "Failed to check for updates: \(error.localizedDescription)"
                ))
            }
        }
    }

    private func handleRelease(_ release: GitHubRelease, userInitiated: Bool) async {
        let remoteVersion = release.tagName.replacingOccurrences(of: "v", with: "")
        print("[UpdateChecker] Remote version: \(remoteVersion), Local version: \(currentVersion)")
        latestVersion = remoteVersion
        releaseNotes = release.body

        let asset = findBestAsset(from: release.assets)
        downloadURL = asset?.browserDownloadURL
        print("[UpdateChecker] Download URL: \(downloadURL?.absoluteString ?? "nil")")

        let hasUpdate = isNewerVersion(remote: remoteVersion, local: currentVersion)
        print("[UpdateChecker] Has update: \(hasUpdate)")
        updateAvailable = hasUpdate

        if hasUpdate {
            showUpdateDialog = true
        } else if userInitiated {
            showNoUpdateAlert()
        }
    }

    private func findBestAsset(from assets: [GitHubAsset]) -> GitHubAsset? {
        let arch = getArchitecture()
        let patterns: [String] = [
            "PasteMemo.*\(arch).*\\.dmg",
            "PasteMemo.*\\.dmg",
            "PasteMemo.*\(arch).*\\.zip",
            "PasteMemo.*\\.zip"
        ]

        for pattern in patterns {
            if let asset = assets.first(where: { $0.name.range(of: pattern, options: .regularExpression) != nil }) {
                return asset
            }
        }

        return assets.first { $0.name.hasSuffix(".dmg") || $0.name.hasSuffix(".zip") }
    }

    private func getArchitecture() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return ""
        #endif
    }

    private func isNewerVersion(remote: String, local: String) -> Bool {
        let remoteComponents = remote.split(separator: ".").compactMap { Int($0) }
        let localComponents = local.split(separator: ".").compactMap { Int($0) }

        let count = max(localComponents.count, remoteComponents.count)
        for i in 0..<count {
            let localPart = i < localComponents.count ? localComponents[i] : 0
            let remotePart = i < remoteComponents.count ? remoteComponents[i] : 0

            if remotePart > localPart {
                return true
            } else if remotePart < localPart {
                return false
            }
        }
        return false
    }

    func downloadUpdate() {
        guard let url = downloadURL else {
            showErrorAlert(message: localizedString(
                zh: "没有可用的下载链接",
                en: "No download URL available"
            ))
            return
        }

        isDownloading = true
        downloadProgress = 0
        downloadedBytes = 0
        totalBytes = 0
        downloadComplete = false

        downloadTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                let tempDir = FileManager.default.temporaryDirectory
                let destinationURL = tempDir.appendingPathComponent(url.lastPathComponent)

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw UpdateError.downloadFailed
                }

                let expectedLength = response.expectedContentLength
                await MainActor.run {
                    self.totalBytes = expectedLength
                }

                FileManager.default.createFile(atPath: destinationURL.path, contents: nil)
                let fileHandle = try FileHandle(forWritingTo: destinationURL)

                var received: Int64 = 0
                let bufferSize: Int64 = 65536

                for try await byte in asyncBytes {
                    try fileHandle.write(contentsOf: [byte])
                    received += 1

                    if received % bufferSize == 0 {
                        await MainActor.run {
                            self.downloadedBytes = received
                            self.downloadProgress = expectedLength > 0
                                ? Double(received) / Double(expectedLength)
                                : 0
                        }
                    }
                }

                try fileHandle.close()

                await MainActor.run {
                    self.downloadedBytes = received
                    self.downloadProgress = 1.0
                    self.downloadComplete = true
                    self.downloadedFileURL = destinationURL
                    self.isDownloading = false
                }

            } catch {
                await MainActor.run {
                    self.isDownloading = false
                    self.showErrorAlert(message: self.localizedString(
                        zh: "下载失败: \(error.localizedDescription)",
                        en: "Download failed: \(error.localizedDescription)"
                    ))
                }
            }
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadProgress = 0
        downloadComplete = false
        downloadedFileURL = nil
    }

    func skipVersion(_ version: String) {
        showUpdateDialog = false
    }

    func installAndRestart() {
        guard let fileURL = downloadedFileURL else {
            showErrorAlert(message: localizedString(
                zh: "没有找到下载的文件",
                en: "Downloaded file not found"
            ))
            return
        }

        let fileExtension = fileURL.pathExtension.lowercased()

        switch fileExtension {
        case "dmg":
            installFromDMG(fileURL: fileURL)
        case "zip":
            installFromZIP(fileURL: fileURL)
        default:
            NSWorkspace.shared.open(fileURL)
        }
    }

    private func installFromDMG(fileURL: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", "-nobrowse", fileURL.path]

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                if let mountedVolume = findMountedVolume(for: fileURL),
                   let appURL = findAppInVolume(mountedVolume) {
                    performAutoReplace(newAppURL: appURL, mountedVolume: mountedVolume)
                } else {
                    if let mountedVolume = findMountedVolume(for: fileURL) {
                        NSWorkspace.shared.open(mountedVolume)
                    } else {
                        NSWorkspace.shared.open(fileURL)
                    }
                    showInstallGuideAlert(volumePath: fileURL.path)
                }
            } else {
                NSWorkspace.shared.open(fileURL)
                showInstallGuideAlert(volumePath: fileURL.path)
            }
        } catch {
            NSWorkspace.shared.open(fileURL)
            showInstallGuideAlert(volumePath: fileURL.path)
        }
    }

    private func findMountedVolume(for dmgURL: URL) -> URL? {
        let fileManager = FileManager.default
        let volumesPath = "/Volumes"

        guard let volumes = try? fileManager.contentsOfDirectory(atPath: volumesPath) else {
            return nil
        }

        let expectedName = dmgURL.deletingPathExtension().lastPathComponent

        for volume in volumes {
            if volume.contains("PasteMemo") || volume == expectedName {
                return URL(fileURLWithPath: volumesPath).appendingPathComponent(volume)
            }
        }

        return nil
    }

    private func findAppInVolume(_ volumeURL: URL) -> URL? {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: volumeURL.path) else {
            return nil
        }

        for item in contents where item.hasSuffix(".app") {
            return volumeURL.appendingPathComponent(item)
        }

        return nil
    }

    private func installFromZIP(fileURL: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", fileURL.path, fileURL.deletingLastPathComponent().path]

        do {
            try process.run()
            process.waitUntilExit()

            let extractedDir = fileURL.deletingLastPathComponent()
            if let appURL = findAppInDirectoryRecursive(extractedDir) {
                performAutoReplace(newAppURL: appURL)
            } else {
                NSWorkspace.shared.open(extractedDir)
                showInstallGuideAlert(volumePath: extractedDir.path)
            }
        } catch {
            NSWorkspace.shared.open(fileURL)
            showInstallGuideAlert(volumePath: fileURL.path)
        }
    }

    private func findAppInDirectory(_ dirURL: URL) -> URL? {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: dirURL.path) else {
            return nil
        }

        for item in contents where item.hasSuffix(".app") {
            return dirURL.appendingPathComponent(item)
        }

        return nil
    }

    private func findAppInDirectoryRecursive(_ dirURL: URL) -> URL? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: dirURL.path) else {
            return nil
        }

        for case let item as String in enumerator {
            if item.hasSuffix(".app") {
                return dirURL.appendingPathComponent(item)
            }
        }

        return nil
    }

    private func performAutoReplace(newAppURL: URL, mountedVolume: URL? = nil) {
        let currentAppURL = Bundle.main.bundleURL
        let appName = currentAppURL.lastPathComponent
        let targetURL: URL

        if currentAppURL.path.hasPrefix("/Applications/") {
            targetURL = URL(fileURLWithPath: "/Applications").appendingPathComponent(appName)
        } else if currentAppURL.path.hasPrefix("/Users/") {
            let homeApps = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications")
            try? FileManager.default.createDirectory(at: homeApps, withIntermediateDirectories: true)
            targetURL = homeApps.appendingPathComponent(appName)
        } else {
            targetURL = currentAppURL
        }

        let scriptContent: String
        if let volume = mountedVolume {
            scriptContent = """
            #!/bin/bash
            sleep 2
            echo "Installing update..."
            if [ -d "\(targetURL.path)" ]; then
                rm -rf "\(targetURL.path)"
            fi
            cp -R "\(newAppURL.path)" "\(targetURL.path)"
            hdiutil detach "\(volume.path)" -quiet
            echo "Launching new version..."
            open "\(targetURL.path)"
            """
        } else {
            scriptContent = """
            #!/bin/bash
            sleep 2
            echo "Installing update..."
            if [ -d "\(targetURL.path)" ]; then
                rm -rf "\(targetURL.path)"
            fi
            cp -R "\(newAppURL.path)" "\(targetURL.path)"
            echo "Launching new version..."
            open "\(targetURL.path)"
            """
        }

        let tempScript = FileManager.default.temporaryDirectory.appendingPathComponent("pasteMemo_update.sh")
        do {
            try scriptContent.write(to: tempScript, atomically: true, encoding: .utf8)
            let chmod = Process()
            chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmod.arguments = ["+x", tempScript.path]
            try chmod.run()
            chmod.waitUntilExit()

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = [tempScript.path]
            try task.run()

            AppDelegate.shouldReallyQuit = true
            NSApp.terminate(nil)
        } catch {
            showErrorAlert(message: localizedString(
                zh: "自动安装失败: \(error.localizedDescription)",
                en: "Auto-install failed: \(error.localizedDescription)"
            ))
            if let volume = mountedVolume {
                NSWorkspace.shared.open(volume)
            }
            showInstallGuideAlert(volumePath: newAppURL.deletingLastPathComponent().path)
        }
    }

    func startPeriodicChecks() {
        periodicCheckTask?.cancel()

        periodicCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                let lastCheckKey = "lastUpdateCheckDate"
                let checkInterval: TimeInterval = 24 * 60 * 60

                if let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date {
                    let elapsed = Date().timeIntervalSince(lastCheck)
                    if elapsed < checkInterval {
                        let delay = checkInterval - elapsed
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                }

                await self?.checkForUpdates(userInitiated: false)
                UserDefaults.standard.set(Date(), forKey: lastCheckKey)

                try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            }
        }
    }

    private func showNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = localizedString(
            zh: "已是最新版本",
            en: "You're up to date!"
        )
        alert.informativeText = localizedString(
            zh: "PasteMemo \(currentVersion) 已经是最新版本。",
            en: "PasteMemo \(currentVersion) is the latest version."
        )
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.tr("action.confirm"))
        alert.runModal()
    }

    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = localizedString(
            zh: "更新出错",
            en: "Update Error"
        )
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.tr("action.confirm"))
        alert.runModal()
    }

    private func showInstallGuideAlert(volumePath: String) {
        let alert = NSAlert()
        alert.messageText = localizedString(
            zh: "请手动安装更新",
            en: "Please Install Manually"
        )
        alert.informativeText = localizedString(
            zh: "已打开安装包，请将 PasteMemo.app 拖拽到 Applications 文件夹完成安装，然后重新启动应用。",
            en: "The installer has been opened. Please drag PasteMemo.app to the Applications folder to complete the installation, then restart the app."
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

// MARK: - GitHub API Models

private struct GitHubRelease: Codable {
    let tagName: String
    let name: String?
    let body: String?
    let draft: Bool
    let prerelease: Bool
    let assets: [GitHubAsset]
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case draft
        case prerelease
        case assets
        case htmlURL = "html_url"
    }
}

private struct GitHubAsset: Codable {
    let name: String
    let browserDownloadURL: URL
    let size: Int
    let contentType: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
        case contentType = "content_type"
    }
}

// MARK: - Update Errors

private enum UpdateError: LocalizedError {
    case invalidResponse
    case rateLimited
    case noReleases
    case downloadFailed
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .rateLimited:
            return "GitHub API rate limit exceeded. Please try again later."
        case .noReleases:
            return "No releases found"
        case .downloadFailed:
            return "Download failed"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        }
    }
}
