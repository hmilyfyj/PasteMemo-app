import CoreGraphics
import Foundation
import Testing
@testable import PasteMemo

@Suite("QuickPanel Configuration Tests")
struct QuickPanelConfigurationTests {
    @Test("Bottom floating compact frame stays inside visible frame")
    func compactFrameFitsVisibleFrame() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let visibleFrame = CGRect(x: 0, y: 38, width: 1440, height: 862)
        let frame = QuickPanelBottomGeometry.frame(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            mode: .compact
        )

        #expect(frame.minX >= screenFrame.minX)
        #expect(frame.maxX <= screenFrame.maxX)
        #expect(frame.minY == visibleFrame.minY + QuickPanelBottomGeometry.bottomInset)
        #expect(frame.height == QuickPanelBottomGeometry.compactHeight)
    }

    @Test("Bottom floating expanded frame grows upward from same bottom anchor")
    func expandedFrameAnchorsToBottom() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let visibleFrame = CGRect(x: 0, y: 24, width: 1728, height: 1056)
        let compact = QuickPanelBottomGeometry.frame(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            mode: .compact
        )
        let expanded = QuickPanelBottomGeometry.frame(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            mode: .expanded
        )

        #expect(compact.minY == expanded.minY)
        #expect(compact.midX == expanded.midX)
        #expect(expanded.height == QuickPanelBottomGeometry.expandedHeight)
        #expect(expanded.maxY <= visibleFrame.maxY)
    }

    @Test("Bottom floating frame respects preferred custom size")
    func customFrameUsesPreferredSize() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let visibleFrame = CGRect(x: 0, y: 38, width: 1440, height: 862)
        let frame = QuickPanelBottomGeometry.frame(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            mode: .compact,
            preferredWidth: 980,
            preferredHeight: 260
        )

        #expect(frame.width == 980)
        #expect(frame.height == 260)
        #expect(frame.minY == visibleFrame.minY + QuickPanelBottomGeometry.bottomInset)
    }

    @Test("Bottom floating custom size is clamped to allowed range")
    func customFrameClampsToBounds() {
        let screenFrame = CGRect(x: 0, y: 0, width: 820, height: 640)
        let visibleFrame = CGRect(x: 0, y: 24, width: 820, height: 560)
        let frame = QuickPanelBottomGeometry.frame(
            screenFrame: screenFrame,
            visibleFrame: visibleFrame,
            mode: .expanded,
            preferredWidth: 300,
            preferredHeight: 1200
        )

        #expect(frame.width == QuickPanelBottomGeometry.minimumWidth)
        #expect(frame.height == visibleFrame.height - QuickPanelBottomGeometry.bottomInset)
        #expect(frame.maxY <= visibleFrame.maxY)
    }

    @Test("Bottom floating keyboard routing matches design")
    func keyboardRouting() {
        #expect(
            QuickPanelKeyboardRouter.intent(
                style: .bottomFloating,
                bottomMode: .compact,
                keyCode: 124,
                hasCommand: false,
                suggestionVisible: false
            ) == .moveSelection(1)
        )
        #expect(
            QuickPanelKeyboardRouter.intent(
                style: .bottomFloating,
                bottomMode: .compact,
                keyCode: 126,
                hasCommand: false,
                suggestionVisible: false
            ) == .switchType(-1)
        )
        #expect(
            QuickPanelKeyboardRouter.intent(
                style: .bottomFloating,
                bottomMode: .expanded,
                keyCode: 53,
                hasCommand: false,
                suggestionVisible: false
            ) == .collapseOrDismiss
        )
        #expect(
            QuickPanelKeyboardRouter.intent(
                style: .bottomFloating,
                bottomMode: .compact,
                keyCode: 31,
                hasCommand: true,
                suggestionVisible: false
            ) == .toggleBottomMode
        )
    }

    @Test("Quick panel style defaults to classic and persists selection")
    func styleStorage() {
        let defaults = UserDefaults.standard
        let key = QuickPanelStyle.storageKey
        let original = defaults.object(forKey: key)
        defaults.removeObject(forKey: key)

        #expect(QuickPanelStyle.stored == .classic)

        defaults.set(QuickPanelStyle.bottomFloating.rawValue, forKey: key)
        #expect(QuickPanelStyle.stored == .bottomFloating)

        if let original {
            defaults.set(original, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
