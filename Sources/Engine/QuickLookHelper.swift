import AppKit
import Quartz

@MainActor
final class QuickLookHelper: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookHelper()

    private var previewURL: URL?
    private var tempFiles: [URL] = []
    private var isShowing = false
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    var onNavigateCards: ((Int) -> Void)?

    private override init() { super.init() }

    var isPreviewVisible: Bool { isShowing }

    func preview(item: ClipItem) {
        let url = prepareURL(for: item)
        guard let url else { return }

        previewURL = url
        isShowing = true

        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self

        QuickPanelWindowController.shared.setQuickLookPreviewVisible(true)
        if panel.isVisible {
            panel.reloadData()
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
        QuickPanelWindowController.shared.keepPanelInteractiveDuringQuickLook()
        installKeyMonitorsIfNeeded()
    }

    func toggle(item: ClipItem) {
        if isShowing {
            closePreview()
        } else {
            preview(item: item)
        }
    }

    func closePreview() {
        isShowing = false
        QLPreviewPanel.shared()?.orderOut(nil)
        removeKeyMonitors()
        cleanupTempFiles()
        QuickPanelWindowController.shared.setQuickLookPreviewVisible(false)
        QuickPanelWindowController.shared.restorePanelInteractionAfterQuickLookClose()
    }

    func canOpenInPreview(item: ClipItem) -> Bool {
        prepareURL(for: item) != nil
    }

    func openInPreviewApp(item: ClipItem) {
        guard let url = prepareURL(for: item) else { return }
        previewURL = url

        if let previewAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: previewAppURL, configuration: configuration) { _, error in
                if error != nil {
                    NSWorkspace.shared.open(url)
                }
            }
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
                if FileManager.default.fileExists(atPath: path) {
                    return URL(fileURLWithPath: path)
                }
            }
            guard let data = item.imageBytesForExport() ?? item.imageData else { return nil }
            return writeTempImageFile(data: data, itemID: item.itemID)

        case .link:
            if let data = item.imageData, !data.isEmpty {
                return writeTempImageFile(data: data, itemID: item.itemID)
            }
            if DataImageURI.isBase64DataImageURI(item.content),
               let data = DataImageURI.decodedImageData(from: item.content) {
                return writeTempImageFile(data: data, itemID: item.itemID)
            }
            return nil

        default:
            let data = item.content.data(using: .utf8) ?? Data()
            return writeTempFile(data: data, name: "preview-\(item.itemID).txt")
        }
    }

    /// Writes clipboard image bytes using the correct extension (TIFF/HEIC/JPEG/…).
    /// Hard-coding `.png` breaks macOS screenshots, which are often TIFF on the pasteboard.
    private func writeTempImageFile(data: Data, itemID: String) -> URL? {
        let ext = ClipboardManager.sniffImageExtension(from: data)
        return writeTempFile(data: data, name: "preview-\(itemID).\(ext)")
    }

    private func writeTempFile(data: Data, name: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PasteMemo-QL")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let url = tempDir.appendingPathComponent(name)
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try data.write(to: url)
            if !tempFiles.contains(url) {
                tempFiles.append(url)
            }
            return url
        } catch {
            return nil
        }
    }

    private func cleanupTempFiles() {
        for url in tempFiles {
            try? FileManager.default.removeItem(at: url)
        }
        tempFiles.removeAll()
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

    // MARK: - QLPreviewPanelDelegate

    nonisolated func previewPanelWillClose(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            isShowing = false
            removeKeyMonitors()
            cleanupTempFiles()
            QuickPanelWindowController.shared.setQuickLookPreviewVisible(false)
            QuickPanelWindowController.shared.restorePanelInteractionAfterQuickLookClose()
        }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard event.type == .keyDown else { return false }
        let keyCode = Int(event.keyCode)
        return MainActor.assumeIsolated {
            handlePreviewKeyCode(keyCode)
        }
    }

    @discardableResult
    private func handlePreviewKeyCode(_ keyCode: Int) -> Bool {
        guard isShowing else { return false }
        switch keyCode {
        case 49, 53:
            closePreview()
            return true
        case 123:
            onNavigateCards?(-1)
            return true
        case 124:
            onNavigateCards?(1)
            return true
        default:
            return false
        }
    }

    private func installKeyMonitorsIfNeeded() {
        if localKeyMonitor == nil {
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.handlePreviewKeyCode(Int(event.keyCode)) ? nil : event
            }
        }
        if globalKeyMonitor == nil {
            globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isShowing else { return }
                switch Int(event.keyCode) {
                case 49, 53:
                    Task { @MainActor [weak self] in self?.closePreview() }
                case 123:
                    Task { @MainActor [weak self] in self?.onNavigateCards?(-1) }
                case 124:
                    Task { @MainActor [weak self] in self?.onNavigateCards?(1) }
                default:
                    break
                }
            }
        }
    }

    private func removeKeyMonitors() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
    }
}
