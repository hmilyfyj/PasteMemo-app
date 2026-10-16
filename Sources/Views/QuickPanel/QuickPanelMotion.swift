import AppKit
import SwiftUI

/// Shared, interruptible feedback. Accessibility state is read at use time in
/// AppKit and supplied by SwiftUI's live environment in persistent views.
enum QuickPanelMotion {
    static let feedbackDuration = 0.12
    static let presentationDuration = 0.18

    /// Bottom entrance: wider travel than the classic styles, with an ease that
    /// covers most of the distance in its first frames so a late main-thread
    /// layout pass cannot leave the panel visibly short of its target.
    static let bottomEntranceDuration = 0.24
    static let bottomEntranceOffset: CGFloat = 28
    static let bottomEntranceStartAlpha: CGFloat = 0.92

    static func allowsMovement(reduceMotion: Bool, enabled: Bool = true) -> Bool {
        enabled && !reduceMotion
    }

    static func feedback(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: feedbackDuration)
    }

    static func launchEnabled(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: QuickPanelSettings.launchAnimationEnabledKey) == nil
            || defaults.bool(forKey: QuickPanelSettings.launchAnimationEnabledKey)
    }

    @MainActor
    static var allowsPresentation: Bool {
        allowsMovement(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                       enabled: launchEnabled(in: .standard))
    }

    @MainActor
    static var allowsAppKitMovement: Bool {
        !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}

/// Own the frame interpolation so a live accessibility change or a new show
/// can cancel it synchronously. NSWindow's animator proxy cannot be cancelled.
@MainActor
final class QuickPanelFrameAnimation {
    private weak var window: NSWindow?
    private let start: NSRect
    let target: NSRect
    private let began = ProcessInfo.processInfo.systemUptime
    private var timer: Timer?

    isolated deinit {
        timer?.invalidate()
    }

    init(window: NSWindow, from start: NSRect, to target: NSRect) {
        self.window = window
        self.start = start
        self.target = target
        window.setFrame(start, display: true)
        window.alphaValue = QuickPanelMotion.bottomEntranceStartAlpha
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard self != nil else { timer.invalidate(); return }
            MainActor.assumeIsolated { self?.tick() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func cancel(finish: Bool) {
        guard let timer else { return }
        timer.invalidate()
        self.timer = nil
        if finish {
            window?.setFrame(target, display: true)
            window?.alphaValue = 1
        }
    }

    private func tick() {
        guard let window else { cancel(finish: false); return }
        let elapsed = ProcessInfo.processInfo.systemUptime - began
        let progress = min(max(elapsed / QuickPanelMotion.bottomEntranceDuration, 0), 1)
        let eased = 1 - pow(1 - progress, 5)
        // Move the origin only: a resize that lands mid-entrance stays in effect
        // instead of being reverted by the next tick.
        var frame = window.frame
        frame.origin.x = start.minX + (target.minX - start.minX) * eased
        frame.origin.y = start.minY + (target.minY - start.minY) * eased
        window.setFrame(frame, display: true)
        window.alphaValue = QuickPanelMotion.bottomEntranceStartAlpha
            + (1 - QuickPanelMotion.bottomEntranceStartAlpha) * eased
        if progress >= 1 { cancel(finish: true) }
    }
}
