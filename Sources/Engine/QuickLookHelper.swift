import AppKit
import Quartz
import UniformTypeIdentifiers

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

    enum PreviewRoute {
        case previewApp
        case quickLook
    }

    /// 查看这个条目该走哪条路，`nil` = 没有可看的东西、动作不该出现。纯判断，不落盘。
    ///
    /// 「能不能看」和「走哪条路」必须由同一次判断给出：菜单用一个条件、执行用另一个条件
    /// 的话，迟早判出不一致——菜单列了行、点下去那条路又拿不出 URL，就成了「点了没反应」。
    ///
    /// 各类型的依据：Quick Look 几乎什么都能显示，所以文本类只要有实质内容就成立；文件类
    /// 要求路径真实存在；`.image` / `.link` 已经在 `canOpenInPreviewApp` 里判过一轮，落到
    /// 这里说明 `prepareURL` 同样拿不出 URL（图片既无原图也无 imageData、链接不带图），
    /// 给它们开 Quick Look 只会是个空窗口。
    func previewRoute(for item: ClipItem) -> PreviewRoute? {
        if canOpenInPreviewApp(item: item) { return .previewApp }
        switch item.contentType {
        case .file, .video, .audio, .document, .archive, .application:
            return firstExistingPath(in: item.content) != nil ? .quickLook : nil
        case .image, .link:
            return nil
        default:
            // 纯空白（几个空格 / 换行）写出去就是一个空白文档，没有查看价值。
            return item.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : .quickLook
        }
    }

    func canPreview(item: ClipItem) -> Bool {
        previewRoute(for: item) != nil
    }

    /// 查看条目：能交给 Preview.app 的交给它，其余走 Quick Look。
    ///
    /// 这里用 `preview` 而不是 `toggle`：菜单里点「快速查看」是「看这一条」，不是开关。
    /// 走 toggle 的话，Quick Look 开着时选中另一条再点，只会把面板关掉（还顺手删了
    /// 临时文件），得再点一次才看得到——那是底栏 ⌘O 同键开关才该有的语义。
    func present(item: ClipItem) {
        switch previewRoute(for: item) {
        case .previewApp: openInPreviewApp(item: item)
        case .quickLook: preview(item: item)
        case nil: break
        }
    }

    /// 「用『预览』打开」这个动作能否成立——纯判断，不落盘。
    ///
    /// 不能拿 `prepareURL() != nil` 当判断：它的 default 分支会把**任意文本**写成临时
    /// .txt 再返回 URL，于是判断对每个条目都为真，文本条目也列出了这个动作。而
    /// Preview.app 打不开 .txt——`NSWorkspace.open` 照样报成功（不进 error 分支，连下面
    /// 的 fallback 都走不到），Preview 被拉到前台却不开窗，用户看到的就是「点了没反应」。
    /// 顺带：走 prepareURL 还意味着每次构建 ⌘K 菜单都往磁盘写一个临时文件，图片条目
    /// 还要把原图字节读进内存。
    ///
    /// 注意和 `preview(item:)` 的区别：Quick Look（⌘O）**能**显示纯文本，所以
    /// prepareURL 的 default 分支对它是对的，那条路径不受这里约束。
    func canOpenInPreviewApp(item: ClipItem) -> Bool {
        switch item.contentType {
        case .image:
            return item.sourceImageFileURL != nil || item.imageData != nil
        case .file, .video, .audio, .document, .archive, .application:
            guard let path = firstExistingPath(in: item.content) else { return false }
            return Self.isPreviewAppOpenable(path: path)
        case .link:
            if let data = item.imageData, !data.isEmpty { return true }
            return DataImageURI.isBase64DataImageURI(item.content)
        default:
            return false
        }
    }

    /// Preview.app 的实际能力边界：图片和 PDF。压缩包 / 音视频 / 纯文本都打不开，
    /// 而且打不开时它不报错、只是不开窗，所以必须在动作出现之前就筛掉。
    private static func isPreviewAppOpenable(path: String) -> Bool {
        guard let type = UTType(filenameExtension: URL(fileURLWithPath: path).pathExtension) else {
            return false
        }
        return type.conforms(to: .image) || type.conforms(to: .pdf)
    }

    /// 多行 content 里第一条真实存在的路径。跳空行 + 展开 `~`，与
    /// `ClipItem.revealableFinderPath` 保持同一套解析（`.first` 不跳空行会把
    /// 开头是空行的条目判成没有路径）。
    private func firstExistingPath(in content: String) -> String? {
        guard let raw = content.components(separatedBy: "\n").first(where: { !$0.isEmpty }) else {
            return nil
        }
        let expanded = (raw as NSString).expandingTildeInPath
        return FileManager.default.fileExists(atPath: expanded) ? expanded : nil
    }

    func openInPreviewApp(item: ClipItem) {
        guard canOpenInPreviewApp(item: item), let url = prepareURL(for: item) else { return }
        previewURL = url
        // 交给 Preview.app 的临时文件不能归 Quick Look 的清理管：cleanupTempFiles() 在用户
        // 下次关掉 Quick Look 时就会跑，那时 Preview 里多半还开着这个文档，删掉它会让
        // Preview 当场变成「文件已移动」。这类文件留给系统回收 TMPDIR。
        tempFiles.removeAll { $0 == url }

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
            return firstExistingPath(in: item.content).map { URL(fileURLWithPath: $0) }

        case .image:
            if item.content != "[Image]", let path = firstExistingPath(in: item.content) {
                return URL(fileURLWithPath: path)
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
