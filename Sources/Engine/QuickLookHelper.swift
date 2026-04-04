import AppKit
import Quartz

@MainActor
final class QuickLookHelper: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookHelper()

    private var previewURL: URL?
    private var tempFiles: [URL] = []

    private override init() { super.init() }

    var isVisible: Bool {
        QLPreviewPanel.shared()?.isVisible == true
    }

    func preview(item: ClipItem) {
        let url = prepareURL(for: item)
        guard let url else { return }

        previewURL = url

        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self

        if panel.isVisible {
            panel.reloadData()
        } else {
            QuickPanelWindowController.shared.setQuickLookPreviewVisible(true)
            panel.makeKeyAndOrderFront(nil)
        }
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
            cleanupTempFiles()
            return
        }
        panel.orderOut(nil)
        QuickPanelWindowController.shared.setQuickLookPreviewVisible(false)
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
        let url = tempDir.appendingPathComponent(name)
        do {
            try data.write(to: url)
            tempFiles.append(url)
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

    nonisolated func previewPanelWillClose(_ panel: QLPreviewPanel!) {
        Task { @MainActor in
            QuickPanelWindowController.shared.setQuickLookPreviewVisible(false)
            cleanupTempFiles()
        }
    }
}
