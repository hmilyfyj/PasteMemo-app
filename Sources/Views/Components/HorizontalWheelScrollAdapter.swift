import SwiftUI
import AppKit

struct HorizontalWheelScrollAdapter: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.coordinator = context.coordinator
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.coordinator = context.coordinator
        context.coordinator.attach(to: nsView)
        context.coordinator.refreshTargetScrollView()
    }

    static func dismantleNSView(_ nsView: TrackingView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        private weak var trackingView: TrackingView?
        private weak var targetScrollView: NSScrollView?
        private var localMonitor: Any?

        deinit {
            if let localMonitor {
                NSEvent.removeMonitor(localMonitor)
            }
        }

        @MainActor
        func attach(to view: TrackingView) {
            trackingView = view
            installMonitorIfNeeded()
            refreshTargetScrollView()
        }

        @MainActor
        func detach() {
            if let localMonitor {
                NSEvent.removeMonitor(localMonitor)
                self.localMonitor = nil
            }
            targetScrollView = nil
            trackingView = nil
        }

        @MainActor
        func refreshTargetScrollView() {
            DispatchQueue.main.async { [weak self] in
                guard let self, let trackingView = self.trackingView else { return }
                self.targetScrollView = trackingView.enclosingScrollView ?? self.findEnclosingScrollView(from: trackingView)
            }
        }

        @MainActor
        private func installMonitorIfNeeded() {
            guard localMonitor == nil else { return }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handleScrollWheel(event) ?? event
            }
        }

        @MainActor
        private func handleScrollWheel(_ event: NSEvent) -> NSEvent? {
            guard let trackingView else { return event }
            guard event.window === trackingView.window else { return event }

            if targetScrollView == nil {
                refreshTargetScrollView()
            }

            let localPoint = trackingView.convert(event.locationInWindow, from: nil)
            guard trackingView.bounds.contains(localPoint) else { return event }
            guard let scrollView = targetScrollView,
                  let documentView = scrollView.documentView else { return event }

            let deltaX = event.scrollingDeltaX
            let deltaY = event.scrollingDeltaY

            // Keep native horizontal gestures untouched; only remap vertical wheel movement.
            guard abs(deltaY) > 0.01, abs(deltaY) > abs(deltaX) else { return event }

            let clipView = scrollView.contentView
            let currentOrigin = clipView.bounds.origin
            let maxOffsetX = max(documentView.frame.width - clipView.bounds.width, 0)
            guard maxOffsetX > 0 else { return event }

            let nextOffsetX = min(max(currentOrigin.x - deltaY, 0), maxOffsetX)
            guard abs(nextOffsetX - currentOrigin.x) > 0.1 else { return event }

            clipView.setBoundsOrigin(NSPoint(x: nextOffsetX, y: currentOrigin.y))
            scrollView.reflectScrolledClipView(clipView)
            return nil
        }

        @MainActor
        private func findEnclosingScrollView(from view: NSView) -> NSScrollView? {
            var current: NSView? = view.superview
            while let candidate = current {
                if let scrollView = candidate as? NSScrollView {
                    return scrollView
                }
                current = candidate.superview
            }
            return nil
        }
    }
}

final class TrackingView: NSView {
    weak var coordinator: HorizontalWheelScrollAdapter.Coordinator?

    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        coordinator?.refreshTargetScrollView()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        coordinator?.refreshTargetScrollView()
    }
}
