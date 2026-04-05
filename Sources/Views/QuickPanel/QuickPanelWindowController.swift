import AppKit
import SwiftUI
import SwiftData

extension Notification.Name {
    static let quickPanelDidShow = Notification.Name("quickPanelDidShow")
    static let quickPanelLiveResizeDidBegin = Notification.Name("quickPanelLiveResizeDidBegin")
    static let quickPanelLiveResizeDidEnd = Notification.Name("quickPanelLiveResizeDidEnd")
}

private let DEFAULT_WIDTH: CGFloat = 750
private let DEFAULT_HEIGHT: CGFloat = 510
private let MIN_WIDTH: CGFloat = 500
private let MIN_HEIGHT: CGFloat = 350
private let VERTICAL_OFFSET: CGFloat = 100
private let CLASSIC_SIZE_KEY = "quickPanelSize"
private let BOTTOM_SIZE_KEY = "quickPanelBottomSize"
private let BOTTOM_WIDTH_IS_CUSTOM_KEY = "quickPanelBottomWidthIsCustom"
private let POSITION_KEY = "quickPanelPosition"

private enum BottomFloatingAnimationState {
    case hidden
    case opening
    case visible
    case closing
}

private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        var frame = frameRect
        guard let screen = screen ?? NSScreen.main else { return frame }
        
        let visibleFrame = screen.visibleFrame
        
        let minVisibleX = visibleFrame.minX
        let maxVisibleX = visibleFrame.maxX - frame.width
        let minVisibleY = visibleFrame.minY
        let maxVisibleY = visibleFrame.maxY - frame.height
        
        frame.origin.x = max(minVisibleX, min(maxVisibleX, frame.origin.x))
        frame.origin.y = max(minVisibleY, min(maxVisibleY, frame.origin.y))
        
        return frame
    }
}

/// Transparent view that absorbs titlebar clicks so they become background drags
private class DragOnlyView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
    override func mouseDown(with event: NSEvent) {
        // Don't call super — prevent system titlebar drag handling
        window?.performDrag(with: event)
    }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

private struct ResizeEdges: OptionSet {
    let rawValue: Int

    static let left = ResizeEdges(rawValue: 1 << 0)
    static let right = ResizeEdges(rawValue: 1 << 1)
    static let top = ResizeEdges(rawValue: 1 << 2)
    static let bottom = ResizeEdges(rawValue: 1 << 3)
}

private final class ResizeHandleOverlayView: NSView {
    weak var panel: NSPanel?
    var isEnabled = false {
        didSet {
            needsDisplay = true
            window?.invalidateCursorRects(for: self)
        }
    }

    private let edgeInset: CGFloat = 14
    private let cornerInset: CGFloat = 22
    private var activeEdges: ResizeEdges = []
    private var initialMouseLocation = NSPoint.zero
    private var initialFrame = NSRect.zero
    private var isLiveResizing = false
    private var pendingFrame: NSRect?
    private var framePump: DispatchSourceTimer?
    private var lastAppliedFrame = NSRect.zero

    override var acceptsFirstResponder: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isEnabled, resizeEdges(at: point) != [] else { return nil }
        return self
    }

    override func resetCursorRects() {
        guard isEnabled else { return }
        let width = bounds.width
        let height = bounds.height
        let horizontalSpan = max(width - cornerInset * 2, 1)
        let verticalSpan = max(height - cornerInset * 2, 1)

        addCursorRect(
            NSRect(x: 0, y: cornerInset, width: edgeInset, height: verticalSpan),
            cursor: .resizeLeftRight
        )
        addCursorRect(
            NSRect(x: width - edgeInset, y: cornerInset, width: edgeInset, height: verticalSpan),
            cursor: .resizeLeftRight
        )
        addCursorRect(
            NSRect(x: cornerInset, y: height - edgeInset, width: horizontalSpan, height: edgeInset),
            cursor: .resizeUpDown
        )
        addCursorRect(
            NSRect(x: cornerInset, y: 0, width: horizontalSpan, height: edgeInset),
            cursor: .resizeUpDown
        )
    }

    override func layout() {
        super.layout()
        window?.invalidateCursorRects(for: self)
    }

    override func mouseDown(with event: NSEvent) {
        guard let panel else { return }
        let point = convert(event.locationInWindow, from: nil)
        activeEdges = resizeEdges(at: point)
        guard activeEdges != [] else { return }
        initialMouseLocation = NSEvent.mouseLocation
        initialFrame = panel.frame
        lastAppliedFrame = panel.frame.integral
        startFramePumpIfNeeded()
        beginLiveResizeIfNeeded()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let panel, activeEdges != [] else { return }
        let mouseLocation = NSEvent.mouseLocation
        let deltaX = mouseLocation.x - initialMouseLocation.x
        let deltaY = mouseLocation.y - initialMouseLocation.y
        var frame = initialFrame

        if activeEdges.contains(.left) {
            frame.origin.x += deltaX
            frame.size.width -= deltaX
        }
        if activeEdges.contains(.right) {
            frame.size.width += deltaX
        }
        if activeEdges.contains(.bottom) {
            frame.origin.y += deltaY
            frame.size.height -= deltaY
        }
        if activeEdges.contains(.top) {
            frame.size.height += deltaY
        }

        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(initialFrame) })
                ?? panel.screen
                ?? NSScreen.screenWithMouse
                ?? NSScreen.main else {
            queueFrameUpdate(frame.integral)
            return
        }

        let allowedMinX = screen.frame.minX + QuickPanelBottomGeometry.horizontalInset
        let allowedMaxX = screen.frame.maxX - QuickPanelBottomGeometry.horizontalInset
        let allowedMinY = screen.visibleFrame.minY + QuickPanelBottomGeometry.bottomInset
        let allowedMaxY = screen.visibleFrame.maxY

        let minWidth = min(panel.minSize.width, allowedMaxX - allowedMinX)
        let maxWidth = min(panel.maxSize.width, allowedMaxX - allowedMinX)
        let minHeight = min(panel.minSize.height, allowedMaxY - allowedMinY)
        let maxHeight = min(panel.maxSize.height, allowedMaxY - allowedMinY)

        if activeEdges.contains(.left) {
            let right = initialFrame.maxX
            frame.size.width = min(max(frame.width, minWidth), maxWidth)
            frame.origin.x = right - frame.width
            frame.origin.x = max(frame.origin.x, allowedMinX)
            frame.size.width = right - frame.origin.x
        } else if activeEdges.contains(.right) {
            frame.size.width = min(max(frame.width, minWidth), maxWidth)
            frame.size.width = min(frame.width, allowedMaxX - frame.origin.x)
        } else {
            frame.size.width = min(max(frame.width, minWidth), maxWidth)
        }

        if activeEdges.contains(.bottom) {
            let top = initialFrame.maxY
            frame.size.height = min(max(frame.height, minHeight), maxHeight)
            frame.origin.y = top - frame.height
            frame.origin.y = max(frame.origin.y, allowedMinY)
            frame.size.height = top - frame.origin.y
        } else if activeEdges.contains(.top) {
            frame.size.height = min(max(frame.height, minHeight), maxHeight)
            frame.size.height = min(frame.height, allowedMaxY - frame.origin.y)
        } else {
            frame.size.height = min(max(frame.height, minHeight), maxHeight)
        }

        frame.origin.x = min(max(frame.origin.x, allowedMinX), allowedMaxX - frame.width)
        frame.origin.y = min(max(frame.origin.y, allowedMinY), allowedMaxY - frame.height)
        queueFrameUpdate(frame.integral)
    }

    override func mouseUp(with event: NSEvent) {
        activeEdges = []
        flushPendingFrameIfNeeded(forceDisplay: true)
        stopFramePump()
        endLiveResizeIfNeeded()
        super.mouseUp(with: event)
    }

    private func beginLiveResizeIfNeeded() {
        guard !isLiveResizing else { return }
        isLiveResizing = true
        QuickPanelWindowController.shared.beginLiveResize(for: panel)
    }

    private func endLiveResizeIfNeeded() {
        guard isLiveResizing else { return }
        isLiveResizing = false
        QuickPanelWindowController.shared.endLiveResize(for: panel)
    }

    private func startFramePumpIfNeeded() {
        guard framePump == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(8), leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            self?.flushPendingFrameIfNeeded()
        }
        framePump = timer
        timer.resume()
    }

    private func stopFramePump() {
        framePump?.setEventHandler {}
        framePump?.cancel()
        framePump = nil
        pendingFrame = nil
    }

    private func queueFrameUpdate(_ frame: NSRect) {
        pendingFrame = frame
    }

    private func flushPendingFrameIfNeeded(forceDisplay: Bool = false) {
        guard let panel, let frame = pendingFrame else { return }
        guard frame != lastAppliedFrame else { return }
        pendingFrame = nil
        lastAppliedFrame = frame
        panel.setFrame(frame, display: forceDisplay)
    }

    private func resizeEdges(at point: NSPoint) -> ResizeEdges {
        guard bounds.contains(point) else { return [] }

        var edges: ResizeEdges = []
        if point.x <= edgeInset { edges.insert(.left) }
        if point.x >= bounds.width - edgeInset { edges.insert(.right) }
        if point.y <= edgeInset { edges.insert(.bottom) }
        if point.y >= bounds.height - edgeInset { edges.insert(.top) }
        return edges
    }
}

@MainActor
final class QuickPanelWindowController {
    static let shared = QuickPanelWindowController()

    private var panel: NSPanel?
    private var resizePersistenceWorkItem: DispatchWorkItem?
    private var isPanelLiveResizing = false
    private var clickOutsideMonitor: Any?
    private var localClickOutsideMonitor: Any?
    private var deactivationObserver: Any?
    private var resignKeyObserver: Any?
    private(set) var previousApp: NSRunningApplication?
    private var isWarmedUp = false
    var isPinned = false
    var suppressDismiss = false
    private var snapGuide: SnapGuideWindow?
    private weak var dragCoverView: NSView?
    private weak var resizeHandleOverlayView: ResizeHandleOverlayView?
    private weak var panelContainerView: NSView?
    private weak var animatedShellView: NSView?
    private(set) var bottomMode: QuickPanelBottomMode = .compact
    private var bottomFloatingAnimationState: BottomFloatingAnimationState = .hidden
    private var pendingDismissCompletions: [() -> Void] = []

    private var panelStyle: QuickPanelStyle {
        QuickPanelStyle.stored
    }

    private var classicPanelWidth: CGFloat {
        let saved = UserDefaults.standard.double(forKey: "\(CLASSIC_SIZE_KEY).width")
        return saved > 0 ? max(saved, MIN_WIDTH) : DEFAULT_WIDTH
    }

    private var classicPanelHeight: CGFloat {
        let saved = UserDefaults.standard.double(forKey: "\(CLASSIC_SIZE_KEY).height")
        return saved > 0 ? max(saved, MIN_HEIGHT) : DEFAULT_HEIGHT
    }

    private init() {}

    var isTransitioning: Bool {
        bottomFloatingAnimationState == .opening || bottomFloatingAnimationState == .closing
    }

    private func bottomPanelWidth(for screenFrame: CGRect) -> CGFloat {
        let widthIsCustom = UserDefaults.standard.bool(forKey: BOTTOM_WIDTH_IS_CUSTOM_KEY)
        let saved = UserDefaults.standard.double(forKey: "\(BOTTOM_SIZE_KEY).width")
        guard widthIsCustom, saved > 0 else {
            return QuickPanelBottomGeometry.panelWidth(for: screenFrame)
        }
        return QuickPanelBottomGeometry.clampedWidth(saved, screenFrame: screenFrame)
    }

    private func bottomPanelHeight(for mode: QuickPanelBottomMode, visibleFrame: CGRect) -> CGFloat {
        let saved = UserDefaults.standard.double(forKey: "\(BOTTOM_SIZE_KEY).\(mode.rawValue).height")
        let preferred = saved > 0 ? saved : QuickPanelBottomGeometry.defaultHeight(for: mode)
        return QuickPanelBottomGeometry.clampedHeight(preferred, visibleFrame: visibleFrame, mode: mode)
    }

    private func persistCurrentPanelSize(_ size: CGSize, panel: NSPanel?) {
        if panelStyle == .bottomFloating {
            let screenFrame = (panel?.screen?.frame)
                ?? NSScreen.screens.first(where: { $0.frame.intersects(panel?.frame ?? .zero) })?.frame
                ?? NSScreen.screenWithMouse?.frame
                ?? NSScreen.main?.frame
                ?? .zero
            let defaultWidth = QuickPanelBottomGeometry.panelWidth(for: screenFrame)
            let widthIsCustom = abs(size.width - defaultWidth) > 1
            UserDefaults.standard.set(widthIsCustom, forKey: BOTTOM_WIDTH_IS_CUSTOM_KEY)
            UserDefaults.standard.set(Double(size.width), forKey: "\(BOTTOM_SIZE_KEY).width")
            UserDefaults.standard.set(Double(size.height), forKey: "\(BOTTOM_SIZE_KEY).\(bottomMode.rawValue).height")
        } else {
            UserDefaults.standard.set(Double(size.width), forKey: "\(CLASSIC_SIZE_KEY).width")
            UserDefaults.standard.set(Double(size.height), forKey: "\(CLASSIC_SIZE_KEY).height")
        }
    }

    private func schedulePanelSizePersistence(for panel: NSPanel) {
        resizePersistenceWorkItem?.cancel()
        let size = panel.frame.size
        let workItem = DispatchWorkItem { [weak self, weak panel] in
            guard let self else { return }
            self.persistCurrentPanelSize(size, panel: panel)
        }
        resizePersistenceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }

    fileprivate func beginLiveResize(for panel: NSPanel?) {
        guard !isPanelLiveResizing else { return }
        isPanelLiveResizing = true
        NotificationCenter.default.post(name: .quickPanelLiveResizeDidBegin, object: panel)
    }

    fileprivate func endLiveResize(for panel: NSPanel?) {
        guard isPanelLiveResizing else { return }
        isPanelLiveResizing = false
        NotificationCenter.default.post(name: .quickPanelLiveResizeDidEnd, object: panel)
        if let panel {
            schedulePanelSizePersistence(for: panel)
        }
    }

    /// Call once at app launch to pre-build the panel off-screen
    func warmUp(clipboardManager: ClipboardManager, modelContainer: ModelContainer) {
        guard !isWarmedUp else { return }
        let panel = buildPanel(clipboardManager: clipboardManager, modelContainer: modelContainer)
        panel.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.displayIfNeeded()
        panel.orderOut(nil)
        self.panel = panel
        bottomFloatingAnimationState = .hidden
        isWarmedUp = true
    }

    func show(clipboardManager: ClipboardManager, modelContainer: ModelContainer) {
        guard !isTransitioning else { return }
        if let existing = panel, existing.isVisible {
            dismiss()
            return
        }

        previousApp = NSWorkspace.shared.frontmostApplication

        if !isWarmedUp {
            warmUp(clipboardManager: clipboardManager, modelContainer: modelContainer)
        }

        guard let panel else { return }

        if panelStyle == .bottomFloating {
            bottomMode = .compact
            bottomFloatingAnimationState = .opening
            pendingDismissCompletions.removeAll()
        }

        AnimationLogger.shared.log("🚀 [QuickPanel] show() called, panelStyle: \(panelStyle)")
        
        applyPanelBehavior(panel)
        
        if panelStyle == .bottomFloating {
            AnimationLogger.shared.log("🚀 [QuickPanel] Calling positionPanelWithAnimation")
            positionPanelWithAnimation(panel)
        } else {
            AnimationLogger.shared.log("🚀 [QuickPanel] Calling positionPanel (classic)")
            positionPanel(panel)
            panel.alphaValue = 1
            panel.orderFrontRegardless()
            panel.makeKey()
        }
        
        installClickOutsideMonitor()
        installDeactivationObserver()
        installMoveObserver()
        NotificationCenter.default.post(name: .quickPanelDidShow, object: nil)
    }

    func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        isPinned = false
        suppressDismiss = false
        removeClickOutsideMonitor()
        removeDeactivationObserver()
        guard let panel else {
            bottomFloatingAnimationState = .hidden
            HotkeyManager.shared.isQuickPanelVisible = false
            completion?()
            return
        }
        removeMoveObserver()
        snapGuide?.orderOut(nil)
        savePosition(panel)

        if let completion {
            pendingDismissCompletions.append(completion)
        }

        guard panel.isVisible else {
            finalizeDismiss(panel)
            return
        }

        guard panelStyle == .bottomFloating, animated else {
            panel.orderOut(nil)
            bottomFloatingAnimationState = .hidden
            HotkeyManager.shared.isQuickPanelVisible = false
            flushPendingDismissCompletions()
            return
        }

        if bottomFloatingAnimationState == .closing {
            return
        }

        bottomFloatingAnimationState = .closing
        animateBottomFloatingDismiss(panel)
    }

    func dismissAndPaste(_ item: ClipItem, clipboardManager: ClipboardManager, addNewLine: Bool = false) {
        let appToRestore = previousApp
        clipboardManager.writeToPasteboard(item)
        item.lastUsedAt = Date()
        SoundManager.playPaste()

        dismiss { [weak self] in
            self?.previousApp = nil

            if let app = appToRestore {
                app.activate()
                clipboardManager.simulatePaste(forceNewLine: addNewLine)
            }
        }
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    var currentPanelFrame: CGRect? {
        panel?.frame
    }

    func setQuickLookPreviewVisible(_ isVisible: Bool) {
        suppressDismiss = isVisible
    }

    func keepPanelInteractiveDuringQuickLook() {
        reclaimPanelFocus()
        // Quick Look 首次创建时会在下一轮 run loop 再次抢回 key window，
        // 这里补一次延迟回收，避免第一次打开后主面板失去键盘/点击响应。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            Task { @MainActor [weak self] in
                self?.reclaimPanelFocus()
            }
        }
    }

    func restorePanelInteractionAfterQuickLookClose() {
        reclaimPanelFocus()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            Task { @MainActor [weak self] in
                self?.reclaimPanelFocus()
            }
        }
    }

    private func reclaimPanelFocus() {
        guard let panel, panel.isVisible else { return }
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
    }

    func setBottomFloatingMode(_ mode: QuickPanelBottomMode, animated: Bool = true) {
        bottomMode = mode
        guard panelStyle == .bottomFloating, let panel, panel.isVisible else { return }
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(panel.frame) })
                ?? NSScreen.screenWithMouse
                ?? panel.screen
                ?? NSScreen.main
                ?? NSScreen.screens.first else { return }
        updateBottomSizeConstraints(for: panel, on: screen)
        let frame = QuickPanelBottomGeometry.frame(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            mode: mode,
            preferredWidth: panel.frame.width,
            preferredHeight: bottomPanelHeight(for: mode, visibleFrame: screen.visibleFrame)
        )
        panel.setFrame(frame, display: true, animate: animated)
    }

    // MARK: - Panel Construction

    private func buildPanel(clipboardManager: ClipboardManager, modelContainer: ModelContainer) -> NSPanel {
        let content = QuickPanelView()
            .environmentObject(clipboardManager)
            .modelContainer(modelContainer)

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: classicPanelWidth, height: classicPanelHeight),
            styleMask: [.nonactivatingPanel, .titled, .borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        // Cover the titlebar with a draggable view so clicks there
        // go through isMovableByWindowBackground instead of system titlebar handling
        let titlebarCover = NSTitlebarAccessoryViewController()
        titlebarCover.layoutAttribute = .top
        let coverView = DragOnlyView(frame: NSRect(x: 0, y: 0, width: 0, height: 1))
        coverView.autoresizingMask = [.width]
        titlebarCover.view = coverView
        panel.addTitlebarAccessoryViewController(titlebarCover)
        dragCoverView = coverView

        let container = NSView(frame: NSRect(x: 0, y: 0, width: classicPanelWidth, height: classicPanelHeight))
        container.wantsLayer = true
        container.layer?.cornerRadius = 16
        container.layer?.masksToBounds = true
        panelContainerView = container

        let animatedShell = NSView(frame: container.bounds)
        animatedShell.wantsLayer = true
        animatedShell.autoresizingMask = [.width, .height]
        animatedShell.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        container.addSubview(animatedShell)
        animatedShellView = animatedShell

        let hostingView = FirstMouseHostingView(rootView: content.ignoresSafeArea())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        animatedShell.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: animatedShell.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: animatedShell.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: animatedShell.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: animatedShell.trailingAnchor),
        ])

        let resizeOverlay = ResizeHandleOverlayView(frame: animatedShell.bounds)
        resizeOverlay.translatesAutoresizingMaskIntoConstraints = false
        resizeOverlay.panel = panel
        animatedShell.addSubview(resizeOverlay)
        NSLayoutConstraint.activate([
            resizeOverlay.topAnchor.constraint(equalTo: animatedShell.topAnchor),
            resizeOverlay.bottomAnchor.constraint(equalTo: animatedShell.bottomAnchor),
            resizeOverlay.leadingAnchor.constraint(equalTo: animatedShell.leadingAnchor),
            resizeOverlay.trailingAnchor.constraint(equalTo: animatedShell.trailingAnchor),
        ])
        resizeHandleOverlayView = resizeOverlay
        container.layoutSubtreeIfNeeded()

        panel.contentView = container
        panel.minSize = NSSize(width: MIN_WIDTH, height: MIN_HEIGHT)

        // Save size when resized
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: panel,
            queue: .main
        ) { [weak self, weak panel] _ in
            Task { @MainActor in
                guard let self, let panel, !self.isPanelLiveResizing else { return }
                self.schedulePanelSizePersistence(for: panel)
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.willStartLiveResizeNotification,
            object: panel,
            queue: .main
        ) { [weak self, weak panel] _ in
            Task { @MainActor in
                self?.beginLiveResize(for: panel)
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didEndLiveResizeNotification,
            object: panel,
            queue: .main
        ) { [weak self, weak panel] _ in
            Task { @MainActor in
                self?.endLiveResize(for: panel)
            }
        }

        return panel
    }

    private func applyPanelBehavior(_ panel: NSPanel) {
        let isBottomFloating = panelStyle == .bottomFloating
        let classicMask: NSWindow.StyleMask = [.nonactivatingPanel, .titled, .borderless, .resizable, .fullSizeContentView]
        let bottomFloatingMask: NSWindow.StyleMask = [.nonactivatingPanel, .borderless, .resizable]

        panel.styleMask = isBottomFloating ? bottomFloatingMask : classicMask
        panel.isMovableByWindowBackground = false
        panel.titlebarAppearsTransparent = !isBottomFloating
        panel.hasShadow = isBottomFloating
        dragCoverView?.isHidden = isBottomFloating
        resizeHandleOverlayView?.isHidden = !isBottomFloating
        resizeHandleOverlayView?.isEnabled = isBottomFloating
        panelContainerView?.layer?.cornerRadius = isBottomFloating ? QuickPanelBottomTheme.windowCornerRadius : 16
        panelContainerView?.layer?.borderWidth = isBottomFloating ? 1 : 0
        panelContainerView?.layer?.borderColor = NSColor.white.withAlphaComponent(isBottomFloating ? 0.06 : 0).cgColor
        animatedShellView?.layer?.backgroundColor = isBottomFloating 
            ? NSColor.controlBackgroundColor.withAlphaComponent(0.95).cgColor
            : NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        panel.minSize = isBottomFloating
            ? NSSize(width: QuickPanelBottomGeometry.minimumWidth, height: QuickPanelBottomGeometry.minimumHeight(for: bottomMode))
            : NSSize(width: MIN_WIDTH, height: MIN_HEIGHT)
        panel.maxSize = isBottomFloating
            ? NSSize(width: QuickPanelBottomGeometry.maxWidth, height: CGFloat.greatestFiniteMagnitude)
            : NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        if !isBottomFloating {
            resetAnimatedShellPresentation()
            bottomFloatingAnimationState = .hidden
        }
    }

    private func updateBottomSizeConstraints(for panel: NSPanel, on screen: NSScreen) {
        let availableWidth = max(screen.frame.width - QuickPanelBottomGeometry.horizontalInset * 2, 0)
        let availableHeight = max(screen.visibleFrame.height - QuickPanelBottomGeometry.bottomInset, 0)
        panel.minSize = NSSize(
            width: min(QuickPanelBottomGeometry.minimumWidth, availableWidth),
            height: min(QuickPanelBottomGeometry.minimumHeight(for: bottomMode), availableHeight)
        )
        panel.maxSize = NSSize(
            width: min(QuickPanelBottomGeometry.maxWidth, availableWidth),
            height: availableHeight
        )
    }

    /// Position panel on the screen where the mouse is, using saved relative offset if available.
    private func positionPanel(_ panel: NSPanel) {
        let screen = NSScreen.screenWithMouse ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let visibleFrame = screen.visibleFrame

        if panelStyle == .bottomFloating {
            updateBottomSizeConstraints(for: panel, on: screen)
            let frame = QuickPanelBottomGeometry.frame(
                screenFrame: screen.frame,
                visibleFrame: visibleFrame,
                mode: bottomMode,
                preferredWidth: bottomPanelWidth(for: screen.frame),
                preferredHeight: bottomPanelHeight(for: bottomMode, visibleFrame: visibleFrame)
            )
            panel.setFrame(frame, display: true)
            return
        }

        panel.setContentSize(NSSize(width: classicPanelWidth, height: classicPanelHeight))
        let hasSaved = UserDefaults.standard.object(forKey: "\(POSITION_KEY).rx") != nil
        if hasSaved {
            // Saved offset is relative to the screen's visible frame (0.0~1.0 ratio)
            let rx = UserDefaults.standard.double(forKey: "\(POSITION_KEY).rx")
            let ry = UserDefaults.standard.double(forKey: "\(POSITION_KEY).ry")
            let x = visibleFrame.origin.x + rx * visibleFrame.width
            let y = visibleFrame.origin.y + ry * visibleFrame.height
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            centerOnScreen(panel, screen: screen)
        }
    }
    
    /// Position panel at its final frame and animate the shell within the clipped container.
    private func positionPanelWithAnimation(_ panel: NSPanel) {
        let screen = NSScreen.screenWithMouse ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let visibleFrame = screen.visibleFrame
        
        updateBottomSizeConstraints(for: panel, on: screen)
        
        let finalFrame = QuickPanelBottomGeometry.frame(
            screenFrame: screen.frame,
            visibleFrame: visibleFrame,
            mode: bottomMode,
            preferredWidth: bottomPanelWidth(for: screen.frame),
            preferredHeight: bottomPanelHeight(for: bottomMode, visibleFrame: visibleFrame)
        )

        AnimationLogger.shared.log("🔍 [Animation Debug]")
        AnimationLogger.shared.log("  screen.frame: \(screen.frame)")
        AnimationLogger.shared.log("  finalFrame: \(finalFrame)")

        let emergeOffset = QuickPanelBottomAnimation.emergeFinalOffset
        var initialFrame = finalFrame
        initialFrame.origin.y = visibleFrame.minY - finalFrame.height
        panel.setFrame(initialFrame, display: true)
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.alphaValue = 1
        prepareBottomFloatingShellForOpen()
        panel.orderFrontRegardless()
        AnimationLogger.shared.log("  After orderFrontRegardless, panel.frame: \(panel.frame)")
        panel.makeKey()
        animateBottomFloatingOpen(panel, finalFrame: finalFrame, emergeOffset: emergeOffset)
    }

    private func prepareBottomFloatingShellForOpen() {
        guard let container = panelContainerView, let shell = animatedShellView else { return }
        let height = container.bounds.height
        let initialOffset = QuickPanelBottomAnimation.openingInitialOffset(for: height)
        shell.frame = container.bounds.offsetBy(dx: 0, dy: initialOffset)
        container.layer?.borderWidth = 0
    }

    private func resetAnimatedShellPresentation() {
        guard let container = panelContainerView, let shell = animatedShellView else { return }
        shell.frame = container.bounds
        container.layer?.borderWidth = 1
    }

    private func setAnimatedShellPresentation(offsetY: CGFloat, alpha: CGFloat) {
        guard let container = panelContainerView, let shell = animatedShellView else { return }
        shell.frame = container.bounds.offsetBy(dx: 0, dy: offsetY)
        shell.alphaValue = alpha
    }

    private func animateBottomFloatingOpen(_ panel: NSPanel, finalFrame: CGRect, emergeOffset: CGFloat) {
        guard let shell = animatedShellView else {
            bottomFloatingAnimationState = .visible
            return
        }

        AnimationLogger.shared.log("  Starting open shell animation...")

        var emergeFrame = finalFrame
        emergeFrame.origin.y = finalFrame.origin.y - QuickPanelBottomGeometry.bottomInset

        NSAnimationContext.runAnimationGroup { context in
            context.duration = QuickPanelBottomAnimation.emergeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            shell.animator().setFrameOrigin(.zero)
            panel.animator().setFrame(emergeFrame, display: true)
        } completionHandler: { [weak self, weak panel] in
            Task { @MainActor [weak self, weak panel] in
                guard let self else { return }
                guard self.bottomFloatingAnimationState == .opening else { return }
                
                AnimationLogger.shared.log("  Starting settle animation...")
                
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = QuickPanelBottomAnimation.emergeSettleDuration
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    context.allowsImplicitAnimation = true
                    panel?.animator().setFrame(finalFrame, display: true)
                } completionHandler: { [weak self, weak panel] in
                    Task { @MainActor [weak self, weak panel] in
                        guard let self else { return }
                        self.resetAnimatedShellPresentation()
                        self.bottomFloatingAnimationState = .visible
                        panel?.makeKey()
                        AnimationLogger.shared.log("  Open shell animation completed")
                    }
                }
            }
        }
    }

    private func animateBottomFloatingDismiss(_ panel: NSPanel) {
        guard let container = panelContainerView, let shell = animatedShellView else {
            finalizeDismiss(panel)
            return
        }

        container.layer?.borderWidth = 0
        let targetOffset = QuickPanelBottomAnimation.closingTargetOffset(for: container.bounds.height)
        AnimationLogger.shared.log("  Starting close shell animation...")

        NSAnimationContext.runAnimationGroup { context in
            context.duration = QuickPanelBottomAnimation.closeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            shell.animator().setFrameOrigin(NSPoint(x: 0, y: targetOffset))
        } completionHandler: { [weak self, weak panel] in
            Task { @MainActor [weak self, weak panel] in
                guard let self else { return }
                self.finalizeDismiss(panel)
                AnimationLogger.shared.log("  Close shell animation completed")
            }
        }
    }

    private func finalizeDismiss(_ panel: NSPanel?) {
        panel?.orderOut(nil)
        bottomFloatingAnimationState = .hidden
        HotkeyManager.shared.isQuickPanelVisible = false
        flushPendingDismissCompletions()
    }

    private func flushPendingDismissCompletions() {
        let completions = pendingDismissCompletions
        pendingDismissCompletions.removeAll()
        completions.forEach { $0() }
    }

    private func centerOnScreen(_ panel: NSPanel, screen: NSScreen) {
        let frame = screen.visibleFrame
        let x = frame.midX - classicPanelWidth / 2
        let y = frame.midY - classicPanelHeight / 2 + VERTICAL_OFFSET
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func resetPosition() {
        guard panelStyle == .classic else { return }
        UserDefaults.standard.removeObject(forKey: "\(POSITION_KEY).rx")
        UserDefaults.standard.removeObject(forKey: "\(POSITION_KEY).ry")
        guard let panel, panel.isVisible else { return }
        let screen = NSScreen.screenWithMouse ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        centerOnScreen(panel, screen: screen)
    }

    private func savePosition(_ panel: NSPanel) {
        guard panelStyle == .classic else { return }
        // Save position as relative offset within the screen's visible frame
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(panel.frame) })
                ?? NSScreen.screenWithMouse else { return }
        let visibleFrame = screen.visibleFrame
        let rx = (panel.frame.origin.x - visibleFrame.origin.x) / visibleFrame.width
        let ry = (panel.frame.origin.y - visibleFrame.origin.y) / visibleFrame.height
        UserDefaults.standard.set(rx, forKey: "\(POSITION_KEY).rx")
        UserDefaults.standard.set(ry, forKey: "\(POSITION_KEY).ry")
    }

    private func installClickOutsideMonitor() {
        let handleOutsideClick: (NSEvent) -> Void = { [weak self] event in
            guard let self else { return }
            if self.isPinned || self.suppressDismiss { return }
            if let panel = self.panel, panel.frame.contains(NSEvent.mouseLocation) { return }
            Task { @MainActor in
                self.dismiss()
            }
        }

        // Global monitor: captures events when app is NOT active
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { handleOutsideClick($0) }

        // Local monitor: captures events when app IS active
        localClickOutsideMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            handleOutsideClick(event)
            return event
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
        if let monitor = localClickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            localClickOutsideMonitor = nil
        }
    }

    private func installDeactivationObserver() {
        // App resign active (e.g. Cmd+Tab when app was active)
        deactivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isPinned, !self.suppressDismiss else { return }
                let isMouseDown = NSEvent.pressedMouseButtons != 0
                let mouseInPanel = self.panel?.frame.contains(NSEvent.mouseLocation) ?? false
                if isMouseDown, mouseInPanel { return }
                self.dismiss()
            }
        }
        // Panel lost key (e.g. another window took focus, or Cmd+Tab)
        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isPinned, !self.suppressDismiss else { return }
                let isMouseDown = NSEvent.pressedMouseButtons != 0
                let mouseInPanel = self.panel?.frame.contains(NSEvent.mouseLocation) ?? false
                if isMouseDown, mouseInPanel { return }
                self.dismiss()
            }
        }
    }

    private func removeDeactivationObserver() {
        if let obs = deactivationObserver {
            NotificationCenter.default.removeObserver(obs)
            deactivationObserver = nil
        }
        if let obs = resignKeyObserver {
            NotificationCenter.default.removeObserver(obs)
            resignKeyObserver = nil
        }
    }

    // MARK: - Snap Guides

    private static let SNAP_THRESHOLD: CGFloat = 20
    private var snappedH = false
    private var snappedV = false
    private var moveObserver: Any?
    private var mouseUpMonitor: Any?
    private var globalMouseUpMonitor: Any?

    private func installMoveObserver() {
        guard panelStyle == .classic else { return }
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleWindowMove()
            }
        }
        let onMouseUp: () -> Void = { [weak self] in
            self?.snapGuide?.orderOut(nil)
            self?.snapToGuideIfNeeded()
            self?.snappedH = false
            self?.snappedV = false
            self?.panel?.makeKey()
        }
        mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { event in
            onMouseUp()
            return event
        }
        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { _ in
            onMouseUp()
        }
    }

    private func removeMoveObserver() {
        if let obs = moveObserver { NotificationCenter.default.removeObserver(obs); moveObserver = nil }
        if let obs = mouseUpMonitor { NSEvent.removeMonitor(obs); mouseUpMonitor = nil }
        if let obs = globalMouseUpMonitor { NSEvent.removeMonitor(obs); globalMouseUpMonitor = nil }
    }

    private func recommendedTopY(screen: NSScreen, panelHeight: CGFloat) -> CGFloat {
        screen.visibleFrame.maxY - VERTICAL_OFFSET - panelHeight
    }

    private func handleWindowMove() {
        guard let panel, NSEvent.pressedMouseButtons & 1 != 0 else { return }
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(panel.frame) })
                ?? NSScreen.screenWithMouse else { return }

        let visibleFrame = screen.visibleFrame
        let panelFrame = panel.frame

        let hDist = abs(panelFrame.midX - visibleFrame.midX)
        let recTopY = recommendedTopY(screen: screen, panelHeight: panelFrame.height)
        let topDist = abs(panelFrame.origin.y - recTopY)
        let vCenterDist = abs(panelFrame.midY - visibleFrame.midY)
        let nearTop = topDist < vCenterDist

        let showH = hDist < Self.SNAP_THRESHOLD
        let showV = (nearTop ? topDist : vCenterDist) < Self.SNAP_THRESHOLD

        if showH, !snappedH { hapticFeedback(); snappedH = true }
        if !showH { snappedH = false }
        if showV, !snappedV { hapticFeedback(); snappedV = true }
        if !showV { snappedV = false }

        let guideTopY = visibleFrame.maxY - VERTICAL_OFFSET
        updateSnapGuide(on: screen, horizontal: showH, verticalCenter: showV && !nearTop, recommendedTop: showV && nearTop, guideTopY: guideTopY)
    }

    private func snapToGuideIfNeeded() {
        guard let panel else { return }
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(panel.frame) })
                ?? NSScreen.screenWithMouse else { return }

        let visibleFrame = screen.visibleFrame
        let panelFrame = panel.frame
        var origin = panelFrame.origin
        var didSnap = false

        if abs(panelFrame.midX - visibleFrame.midX) < Self.SNAP_THRESHOLD {
            origin.x = visibleFrame.midX - panelFrame.width / 2; didSnap = true
        }
        let recTopY = recommendedTopY(screen: screen, panelHeight: panelFrame.height)
        if abs(panelFrame.origin.y - recTopY) < Self.SNAP_THRESHOLD {
            origin.y = recTopY; didSnap = true
        } else if abs(panelFrame.midY - visibleFrame.midY) < Self.SNAP_THRESHOLD {
            origin.y = visibleFrame.midY - panelFrame.height / 2; didSnap = true
        }
        if didSnap { panel.setFrameOrigin(origin) }
    }

    private func hapticFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func updateSnapGuide(on screen: NSScreen, horizontal: Bool, verticalCenter: Bool, recommendedTop: Bool, guideTopY: CGFloat) {
        if horizontal || verticalCenter || recommendedTop {
            let guide = snapGuide ?? SnapGuideWindow(screen: screen)
            guide.update(screen: screen, showHorizontal: horizontal, showVerticalCenter: verticalCenter, showRecommendedTop: recommendedTop, recommendedTopY: guideTopY)
            guide.orderFront(nil)
            snapGuide = guide
        } else {
            snapGuide?.orderOut(nil)
        }
    }
}

// MARK: - Snap Guide Overlay Window

private class SnapGuideWindow: NSWindow {
    private let guideView = SnapGuideView()

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.isReleasedWhenClosed = false
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating + 1
        self.ignoresMouseEvents = true
        self.hasShadow = false
        self.contentView = guideView
    }

    func update(screen: NSScreen, showHorizontal: Bool, showVerticalCenter: Bool, showRecommendedTop: Bool, recommendedTopY: CGFloat) {
        setFrame(screen.frame, display: false)
        guideView.showHorizontal = showHorizontal
        guideView.showVerticalCenter = showVerticalCenter
        guideView.showRecommendedTop = showRecommendedTop
        // Convert screen coordinate to view coordinate
        guideView.recommendedTopLocalY = recommendedTopY - screen.frame.origin.y
        guideView.needsDisplay = true
    }
}

private class SnapGuideView: NSView {
    var showHorizontal = false
    var showVerticalCenter = false
    var showRecommendedTop = false
    var recommendedTopLocalY: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let color = NSColor.gray.withAlphaComponent(0.4).cgColor
        ctx.setStrokeColor(color)
        ctx.setLineWidth(1.5)
        ctx.setLineDash(phase: 0, lengths: [6, 4])

        if showHorizontal {
            ctx.move(to: CGPoint(x: bounds.midX, y: bounds.minY))
            ctx.addLine(to: CGPoint(x: bounds.midX, y: bounds.maxY))
            ctx.strokePath()
        }
        if showVerticalCenter {
            ctx.move(to: CGPoint(x: bounds.minX, y: bounds.midY))
            ctx.addLine(to: CGPoint(x: bounds.maxX, y: bounds.midY))
            ctx.strokePath()
        }
        if showRecommendedTop {
            ctx.move(to: CGPoint(x: bounds.minX, y: recommendedTopLocalY))
            ctx.addLine(to: CGPoint(x: bounds.maxX, y: recommendedTopLocalY))
            ctx.strokePath()
        }
    }
}

extension NSScreen {
    static var screenWithMouse: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return screens.first { $0.frame.contains(mouseLocation) }
    }
}
