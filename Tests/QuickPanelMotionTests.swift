import Foundation
import AppKit
import SwiftUI
import Testing
@testable import PasteMemo

@Suite("Quick panel motion policy")
struct QuickPanelMotionTests {
    @MainActor
    @Test("Cancelling movement finishes once and never restores an idle window's old frame")
    func cancelFramePresentation() {
        let start = NSRect(x: 10, y: 10, width: 300, height: 200)
        let target = NSRect(x: 10, y: 22, width: 300, height: 200)
        let window = NSWindow(contentRect: start, styleMask: .borderless, backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let animation = QuickPanelFrameAnimation(window: window, from: start, to: target)
        #expect(window.frame == start)
        animation.cancel(finish: true)
        #expect(window.frame == target)
        #expect(window.alphaValue == 1)
        let resized = NSRect(x: 50, y: 50, width: 350, height: 250)
        window.setFrame(resized, display: false)
        animation.cancel(finish: true)
        #expect(window.frame == resized)
    }

    @MainActor
    @Test("Header foreground follows the tuned gradient, including pale source icons")
    func sourceContrast() {
        #expect(QuickPanelBottomTheme.headerForeground(for: [Color(white: 0.95), Color(white: 0.85)]) == .black)
        #expect(QuickPanelBottomTheme.headerForeground(for: [Color(white: 0.2), Color(white: 0.1)]) == .white)
    }
    @Test("Reduced motion and disabled presentation both suppress movement",
          arguments: [false, true], [false, true])
    func movementPolicy(reduced: Bool, enabled: Bool) {
        #expect(QuickPanelMotion.allowsMovement(reduceMotion: reduced, enabled: enabled) == (enabled && !reduced))
    }

    @Test("Reduced motion removes feedback animation")
    func reducedMotionFeedback() {
        #expect(QuickPanelMotion.feedback(reduceMotion: true) == nil)
        #expect(QuickPanelMotion.feedback(reduceMotion: false) != nil)
    }

    @Test("Launch defaults and preference changes are read without caching")
    func launchPreference() throws {
        let domain = "PasteMemoMotionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        #expect(QuickPanelMotion.launchEnabled(in: defaults))
        defaults.set(false, forKey: QuickPanelSettings.launchAnimationEnabledKey)
        #expect(!QuickPanelMotion.launchEnabled(in: defaults))
        defaults.set(true, forKey: QuickPanelSettings.launchAnimationEnabledKey)
        #expect(QuickPanelMotion.launchEnabled(in: defaults))
    }
}
