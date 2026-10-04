import AppKit
import SwiftUI

enum HorizontalMouseWheelScroll {
    /// Precise vertical events can also come from mouse smoothing tools such as
    /// Mos. Preserve existing horizontal/diagonal gestures; map vertical input.
    @MainActor
    static func scroll(_ event: NSEvent, in scrollView: NSScrollView) -> Bool {
        guard event.type == .scrollWheel,
              event.scrollingDeltaX == 0,
              event.scrollingDeltaY != 0,
              scrollView.documentView != nil else { return false }
        let viewport = scrollView.contentView
        guard viewport.documentRect.width > viewport.bounds.width else { return false }
        let distance = event.scrollingDeltaY
            * (event.hasPreciseScrollingDeltas ? 1 : scrollView.horizontalLineScroll)
        var proposed = viewport.bounds
        proposed.origin.x -= distance
        viewport.scroll(to: viewport.constrainBoundsRect(proposed).origin)
        scrollView.reflectScrolledClipView(viewport)
        return true
    }
}

/// Attach to horizontal ScrollView content so the marker has an enclosing
/// NSScrollView. The local monitor leaves all hit testing and gestures intact.
struct HorizontalMouseWheelScrollBridge: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = MarkerView()
        context.coordinator.view = view
        context.coordinator.start()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class MarkerView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    @MainActor
    final class Coordinator {
        weak var view: NSView?
        private var monitor: Any?

        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                let handled = MainActor.assumeIsolated {
                    self?.handle(event) ?? false
                }
                return handled ? nil : event
            }
        }

        func handle(_ event: NSEvent) -> Bool {
            guard let view,
                  let window = view.window, window.isVisible,
                  event.windowNumber == window.windowNumber,
                  !view.isHiddenOrHasHiddenAncestor,
                  let scrollView = view.enclosingScrollView else { return false }
            let viewport = scrollView.contentView
            let point = viewport.convert(event.locationInWindow, from: nil)
            guard viewport.bounds.contains(point) else { return false }
            // A search suggestions scroll view can overlay the cards in the
            // same window. Only translate events targeting this scroll view.
            guard let content = window.contentView else { return false }
            let hitPoint = content.superview?.convert(event.locationInWindow, from: nil) ?? event.locationInWindow
            guard let hit = content.hitTest(hitPoint),
                  hit === scrollView || hit.enclosingScrollView === scrollView else { return false }
            return HorizontalMouseWheelScroll.scroll(event, in: scrollView)
        }

        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}
