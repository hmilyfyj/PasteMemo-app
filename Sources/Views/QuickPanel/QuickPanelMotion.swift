import AppKit
import SwiftUI

/// Shared, interruptible feedback. Accessibility state is read at use time in
/// AppKit and supplied by SwiftUI's live environment in persistent views.
enum QuickPanelMotion {
    static let feedbackDuration = 0.12
    static let presentationDuration = 0.18

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
    private let target: NSRect
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
        window.alphaValue = 0.94
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
        let progress = min(max(elapsed / QuickPanelMotion.presentationDuration, 0), 1)
        let eased = 1 - pow(1 - progress, 3)
        let frame = NSRect(
            x: start.minX + (target.minX - start.minX) * eased,
            y: start.minY + (target.minY - start.minY) * eased,
            width: start.width + (target.width - start.width) * eased,
            height: start.height + (target.height - start.height) * eased
        )
        window.setFrame(frame, display: true)
        window.alphaValue = 0.94 + 0.06 * eased
        if progress >= 1 { cancel(finish: true) }
    }
}
