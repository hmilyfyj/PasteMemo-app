# Quick panel appearance and motion

- Reuse `appearanceMode` (system/light/dark) and `AppDelegate.applyAppearance`; bottom UI reads SwiftUI's live color scheme. `QuickPanelBottomTheme` owns adaptive shell, card, section, shadow and foreground values.
- The bottom card rail has no decorative section fill or border in either theme: the window shell remains visible between cards. Preserve rail padding, native scrolling and drop handlers; empty states and expanded preview retain their section decoration.
- Selection must preserve the source-derived header gradient and use a separate outline. Choose header black/white foreground by gradient contrast. Image footers keep white text over a dark scrim.
- `QuickPanelMotion` owns 120ms feedback and 180ms presentation. SwiftUI reads live `accessibilityReduceMotion`; AppKit checks `NSWorkspace` and observes accessibility display changes. Preserve the launch-animation preference.
- Repeated keyboard navigation, paste, dismissal and focus restoration stay immediate. Bottom entrance moves 12pt only when movement is allowed. Keep lightweight live-resize rendering.
- Frame animation has one cancellable owner. Invalidate its timer on completion, cancellation and owner release; cancelling an idle/completed animator cannot restore obsolete geometry.
- Validate contrast and real NSWindow cancellation with isolated tests; use synthetic clipboard content for visual attachments. Native drag/paste verification needs an interactive session and accessibility permission, so record any unavailable checks explicitly.
