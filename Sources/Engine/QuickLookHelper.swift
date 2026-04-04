import AppKit
import Quartz

@MainActor
final class QuickLookHelper: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookHelper()

    private var previewURL: URL?
    private var tempFiles: [URL] = []
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?

    private override init() { super.init() }

    var isVisible: Bool {
        QLPreviewPanel.shared()?.isVisible == true
    }

    func preview(item: ClipItem) {
        let url = prepareURL(for: item)
        guard let url else {
            closePreview()
            return
        }

        previewURL = url

        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self

        if panel.isVisible {
            panel.reloadData()
            cleanupTempFiles(keeping: previewURL)
            QuickPanelWindowController.shared.keepPanelInteractiveDuringQuickLook()
        } else {
            QuickPanelWindowController.shared.setQuickLookPreviewVisible(true)
            panel.makeKeyAndOrderFront(nil)
            QuickPanelWindowController.shared.keepPanelInteractiveDuringQuickLook()
        }
        installInteractionMonitorsIfNeeded()
    }

    func toggle(item: ClipItem) {
        if isVisible {
            closePreview()
        } else {
            preview(item: item)
        }
    }

    func closePreview() {
        guard let panel = QLPreviewPanel.shared(), panel.isVisible else {
            QuickPanelWindowController.shared.setQuickLookPreviewVisible(false)
            removeInteractionMonitors()
            cleanupTempFiles()
            return
        }
        panel.orderOut(nil)
        QuickPanelWindowController.shared.setQuickLookPreviewVisible(false)
        QuickPanelWindowController.shared.restorePanelInteractionAfterQuickLookClose()
        removeInteractionMonitors()
        cleanupTempFiles()
    }

    func canOpenInPreview(item: ClipItem) -> Bool {
        if item.contentType == .image {
            return item.imageData != nil || item.content != "[Image]"
        }

        switch item.contentType {
        case .file, .document, .video, .audio:
            return !item.content.contains("\n")
        default:
            return false
        }
    }

    func openInPreviewApp(item: ClipItem) {
        guard canOpenInPreview(item: item), let url = prepareURL(for: item) else { return }
        previewURL = url

        if let previewAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: previewAppURL, configuration: configuration) { _, _ in }
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    private func prepareURL(for item: ClipItem) -> URL? {
        switch item.contentType {
        case .file, .video, .audio, .document, .archive, .application:
            let path = item.content.components(separatedBy: "\n").first ?? ""
            let url = URL(fileURLWithPath: path)
            return FileManager.default.fileExists(atPath: path) ? url : nil

        case .image:
            if item.content != "[Image]" {
                let path = item.content.components(separatedBy: "\n").first ?? ""
                return FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
            }
            guard let data = item.imageData else { return nil }
            return writeTempFile(data: data, name: "preview.png")

        case .link:
            return URL(string: item.content.trimmingCharacters(in: .whitespacesAndNewlines))

        default:
            let data = item.content.data(using: .utf8) ?? Data()
            return writeTempFile(data: data, name: "preview.txt")
        }
    }

    private func writeTempFile(data: Data, name: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PasteMemo-QL")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileName = "\(UUID().uuidString)-\(name)"
        let url = tempDir.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            tempFiles.append(url)
            return url
        } catch {
            return nil
        }
    }

    private func cleanupTempFiles() {
        cleanupTempFiles(keeping: nil)
    }

    private func cleanupTempFiles(keeping currentURL: URL?) {
        for url in tempFiles {
            if let currentURL, url == currentURL { continue }
            try? FileManager.default.removeItem(at: url)
        }
        if let currentURL {
            tempFiles = tempFiles.filter { $0 == currentURL }
        } else {
            tempFiles.removeAll()
        }
    }

    // MARK: - QLPreviewPanelDataSource

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        1
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        MainActor.assumeIsolated {
            previewURL as? NSURL
        }
    }

    nonisolated func previewPanelWillClose(_ panel: QLPreviewPanel!) {
        Task { @MainActor in
            QuickPanelWindowController.shared.setQuickLookPreviewVisible(false)
            QuickPanelWindowController.shared.restorePanelInteractionAfterQuickLookClose()
            removeInteractionMonitors()
            cleanupTempFiles()
        }
    }

    private func installInteractionMonitorsIfNeeded() {
        if localKeyMonitor == nil {
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isVisible else { return event }
                switch Int(event.keyCode) {
                case 49, 53:
                    self.closePreview()
                    return nil
                default:
                    return event
                }
            }
        }

        if globalKeyMonitor == nil {
            globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isVisible else { return }
                switch Int(event.keyCode) {
                case 49, 53:
                    Task { @MainActor [weak self] in
                        self?.closePreview()
                    }
                default:
                    break
                }
            }
        }

        if localMouseMonitor == nil {
            localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self, self.isVisible else { return event }
                guard let quickPanelFrame = QuickPanelWindowController.shared.currentPanelFrame else { return event }

                let mouseLocation = NSEvent.mouseLocation
                
                // 获取 Quick Look 面板的 frame
                let qlPanelFrame = QLPreviewPanel.shared()?.frame
                
                // 点击 Quick Look 面板内部：不关闭任何东西，允许用户与预览面板交互
                if let qlFrame = qlPanelFrame, qlFrame.contains(mouseLocation) {
                    return event
                }
                
                // 点击剪贴板面板内部：保持面板交互性
                if quickPanelFrame.contains(mouseLocation) {
                    QuickPanelWindowController.shared.keepPanelInteractiveDuringQuickLook()
                    return event
                }
                
                // 点击两个面板外部：关闭预览，并根据固定状态决定是否关闭剪贴板面板
                self.closePreview()
                if !QuickPanelWindowController.shared.isPinned {
                    Task { @MainActor in
                        QuickPanelWindowController.shared.dismiss()
                    }
                }
                return nil
            }
        }

        if globalMouseMonitor == nil {
            globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                guard let self, self.isVisible else { return }
                guard let quickPanelFrame = QuickPanelWindowController.shared.currentPanelFrame else { return }
                
                let mouseLocation = NSEvent.mouseLocation
                
                // 获取 Quick Look 面板的 frame
                let qlPanelFrame = QLPreviewPanel.shared()?.frame
                
                // 点击 Quick Look 面板内部：不关闭任何东西，允许用户与预览面板交互
                if let qlFrame = qlPanelFrame, qlFrame.contains(mouseLocation) {
                    return
                }
                
                // 点击剪贴板面板内部：不关闭任何东西
                if quickPanelFrame.contains(mouseLocation) {
                    return
                }
                
                // 点击两个面板外部：关闭预览，并根据固定状态决定是否关闭剪贴板面板
                Task { @MainActor [weak self] in
                    self?.closePreview()
                    if !QuickPanelWindowController.shared.isPinned {
                        QuickPanelWindowController.shared.dismiss()
                    }
                }
            }
        }

    }

    private func removeInteractionMonitors() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }
}
