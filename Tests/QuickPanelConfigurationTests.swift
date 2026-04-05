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

        #expect(frame.width == screenFrame.width - QuickPanelBottomGeometry.horizontalInset * 2)
        #expect(frame.height == visibleFrame.height - QuickPanelBottomGeometry.bottomInset)
        #expect(frame.maxY <= visibleFrame.maxY)
    }

    @Test("Bottom floating default width respects horizontal insets")
    func defaultWidthUsesFullScreenWidth() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)

        #expect(QuickPanelBottomGeometry.panelWidth(for: screenFrame) == screenFrame.width - QuickPanelBottomGeometry.horizontalInset * 2)
        #expect(QuickPanelBottomGeometry.legacyDefaultWidth(for: screenFrame) == screenFrame.width - 20)
        #expect(QuickPanelBottomGeometry.shouldUpgradeSavedWidthToCurrentDefault(screenFrame.width - 20, screenFrame: screenFrame))
        #expect(!QuickPanelBottomGeometry.shouldUpgradeSavedWidthToCurrentDefault(1200, screenFrame: screenFrame))
    }

    @Test("Bottom floating width remains current default when legacy custom flag is absent")
    func bottomWidthDefaultsToCurrentScreenWidthWithoutCustomFlag() {
        let defaults = UserDefaults.standard
        let widthKey = "quickPanelBottomSize.width"
        let customKey = "quickPanelBottomWidthIsCustom"
        let originalWidth = defaults.object(forKey: widthKey)
        let originalCustom = defaults.object(forKey: customKey)
        let screenFrame = CGRect(x: 0, y: 0, width: 3360, height: 1859)

        defaults.set(1512, forKey: widthKey)
        defaults.removeObject(forKey: customKey)

        let widthIsCustom = defaults.bool(forKey: customKey)
        let resolvedWidth = widthIsCustom
            ? QuickPanelBottomGeometry.clampedWidth(CGFloat(defaults.double(forKey: widthKey)), screenFrame: screenFrame)
            : QuickPanelBottomGeometry.panelWidth(for: screenFrame)

        #expect(!widthIsCustom)
        #expect(resolvedWidth == screenFrame.width - QuickPanelBottomGeometry.horizontalInset * 2)

        if let originalWidth {
            defaults.set(originalWidth, forKey: widthKey)
        } else {
            defaults.removeObject(forKey: widthKey)
        }

        if let originalCustom {
            defaults.set(originalCustom, forKey: customKey)
        } else {
            defaults.removeObject(forKey: customKey)
        }
    }

    @Test("Bottom floating keyboard routing matches design")
    func keyboardRouting() {
        #expect(
            QuickPanelKeyboardRouter.intent(
                style: .bottomFloating,
                bottomMode: .compact,
                keyCode: 124,
                hasCommand: false,
                suggestionVisible: false,
                searchFocused: false
            ) == .moveSelection(1)
        )
        #expect(
            QuickPanelKeyboardRouter.intent(
                style: .bottomFloating,
                bottomMode: .compact,
                keyCode: 126,
                hasCommand: false,
                suggestionVisible: false,
                searchFocused: false
            ) == .switchType(-1)
        )
        #expect(
            QuickPanelKeyboardRouter.intent(
                style: .bottomFloating,
                bottomMode: .expanded,
                keyCode: 53,
                hasCommand: false,
                suggestionVisible: false,
                searchFocused: false
            ) == .collapseOrDismiss
        )
        #expect(
            QuickPanelKeyboardRouter.intent(
                style: .bottomFloating,
                bottomMode: .compact,
                keyCode: 31,
                hasCommand: true,
                suggestionVisible: false,
                searchFocused: false
            ) == .toggleBottomMode
        )
        #expect(
            QuickPanelKeyboardRouter.intent(
                style: .bottomFloating,
                bottomMode: .compact,
                keyCode: 49,
                hasCommand: false,
                suggestionVisible: false,
                searchFocused: false
            ) == .togglePreview
        )
        #expect(
            QuickPanelKeyboardRouter.intent(
                style: .bottomFloating,
                bottomMode: .compact,
                keyCode: 49,
                hasCommand: false,
                suggestionVisible: false,
                searchFocused: true
            ) == nil
        )
    }

    @Test("Bottom floating opening animation reveals only the header strip")
    func bottomOpeningAnimationUsesRevealHeight() {
        let compactOffset = QuickPanelBottomAnimation.openingInitialOffset(for: QuickPanelBottomGeometry.compactHeight)
        let expandedOffset = QuickPanelBottomAnimation.openingInitialOffset(for: QuickPanelBottomGeometry.expandedHeight)

        #expect(compactOffset == -(QuickPanelBottomGeometry.compactHeight - QuickPanelBottomAnimation.revealHeight))
        #expect(expandedOffset == -(QuickPanelBottomGeometry.expandedHeight - QuickPanelBottomAnimation.revealHeight))
        #expect(compactOffset < 0)
        #expect(expandedOffset < compactOffset)
    }

    @Test("Bottom floating closing animation retreats below the shell while leaving a small lip")
    func bottomClosingAnimationUsesCloseRevealHeight() {
        let compactOffset = QuickPanelBottomAnimation.closingTargetOffset(for: QuickPanelBottomGeometry.compactHeight)
        let expandedOffset = QuickPanelBottomAnimation.closingTargetOffset(for: QuickPanelBottomGeometry.expandedHeight)

        #expect(compactOffset == -(QuickPanelBottomGeometry.compactHeight - QuickPanelBottomAnimation.closeRevealHeight))
        #expect(expandedOffset == -(QuickPanelBottomGeometry.expandedHeight - QuickPanelBottomAnimation.closeRevealHeight))
        #expect(compactOffset < 0)
        #expect(expandedOffset < compactOffset)
    }

    @Test("Bottom floating animation constants preserve a valid reveal window")
    func bottomAnimationConstantsStayInRange() {
        #expect(QuickPanelBottomAnimation.revealHeight > 0)
        #expect(QuickPanelBottomAnimation.closeRevealHeight > 0)
        #expect(QuickPanelBottomAnimation.revealHeight < QuickPanelBottomGeometry.minimumCompactHeight)
        #expect(QuickPanelBottomAnimation.closeRevealHeight < QuickPanelBottomGeometry.minimumCompactHeight)
        #expect(QuickPanelBottomAnimation.openOvershoot >= 0)
        #expect(QuickPanelBottomAnimation.openDuration > 0)
        #expect(QuickPanelBottomAnimation.settleDuration > 0)
        #expect(QuickPanelBottomAnimation.closeDuration > 0)
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
