import SwiftUI
import SwiftData
import Quartz
import AppKit

enum QuickFilter: Equatable {
    case all
    case pinned
    case type(ClipContentType)
}

let PANEL_WIDTH: CGFloat = 750
let PANEL_HEIGHT: CGFloat = 510
let LIST_WIDTH: CGFloat = 340

struct BottomCardLayoutMetrics {
    let railHeight: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let spacing: CGFloat
}

struct BottomClipEnsureVisibleProbe: NSViewRepresentable {
    let itemID: PersistentIdentifier
    let activeID: PersistentIdentifier?
    let edgePadding: CGFloat
    let animationDuration: TimeInterval

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.coordinator = context.coordinator
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: ProbeView, context: Context) {
        nsView.coordinator = context.coordinator
        context.coordinator.attach(to: nsView)
        context.coordinator.update(
            itemID: itemID,
            activeID: activeID,
            edgePadding: edgePadding,
            animationDuration: animationDuration
        )
    }

    static func dismantleNSView(_ nsView: ProbeView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        weak var probeView: ProbeView?
        var lastHandledSelectionID: PersistentIdentifier?

        @MainActor
        func attach(to view: ProbeView) {
            probeView = view
        }

        @MainActor
        func detach() {
            probeView = nil
            lastHandledSelectionID = nil
        }

        @MainActor
        func update(
            itemID: PersistentIdentifier,
            activeID: PersistentIdentifier?,
            edgePadding: CGFloat,
            animationDuration: TimeInterval
        ) {
            guard activeID == itemID else { return }
            guard lastHandledSelectionID != activeID else { return }

            lastHandledSelectionID = activeID

            DispatchQueue.main.async { [weak self] in
                self?.ensureVisible(edgePadding: edgePadding, animationDuration: animationDuration)
            }
        }

        @MainActor
        func ensureVisible(edgePadding: CGFloat, animationDuration: TimeInterval) {
            guard let probeView,
                  let scrollView = findEnclosingScrollView(from: probeView),
                  let documentView = scrollView.documentView else { return }

            let clipView = scrollView.contentView
            let visibleRect = clipView.bounds
            let cardFrame = probeView.convert(probeView.bounds, to: documentView)
            let minVisibleX = visibleRect.minX + edgePadding
            let maxVisibleX = visibleRect.maxX - edgePadding
            let tolerance: CGFloat = 0.5

            var targetOriginX = visibleRect.origin.x

            if cardFrame.minX < minVisibleX - tolerance {
                targetOriginX -= (minVisibleX - cardFrame.minX)
            } else if cardFrame.maxX > maxVisibleX + tolerance {
                targetOriginX += (cardFrame.maxX - maxVisibleX)
            } else {
                return
            }

            let maxOffsetX = max(documentView.bounds.width - visibleRect.width, 0)
            targetOriginX = min(max(targetOriginX, 0), maxOffsetX)

            guard abs(targetOriginX - visibleRect.origin.x) > tolerance else { return }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                clipView.animator().setBoundsOrigin(
                    NSPoint(x: targetOriginX, y: visibleRect.origin.y)
                )
            } completionHandler: {
                Task { @MainActor in
                    scrollView.reflectScrolledClipView(clipView)
                }
            }
        }

        @MainActor
        func findEnclosingScrollView(from view: NSView) -> NSScrollView? {
            var current: NSView? = view
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

final class ProbeView: NSView {
    weak var coordinator: BottomClipEnsureVisibleProbe.Coordinator?

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        coordinator?.attach(to: self)
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        coordinator?.attach(to: self)
    }
}

struct LiveResizeCardSnapshot: Identifiable, Equatable {
    let id: String
    let isSelected: Bool
}

struct LiveResizeRailRepresentable: NSViewRepresentable {
    let cards: [LiveResizeCardSnapshot]
    let metrics: BottomCardLayoutMetrics

    func makeNSView(context: Context) -> LiveResizeRailNSView {
        LiveResizeRailNSView()
    }

    func updateNSView(_ nsView: LiveResizeRailNSView, context: Context) {
        nsView.update(cards: cards, metrics: metrics)
    }
}

final class LiveResizeRailNSView: NSView {
    var cards: [LiveResizeCardSnapshot] = []
    var metrics = BottomCardLayoutMetrics(
        railHeight: 180,
        cardWidth: 160,
        cardHeight: 160,
        horizontalPadding: 10,
        verticalPadding: 10,
        spacing: 12
    )
    var cardLayers: [LiveResizeSkeletonCardLayer] = []

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = true
        layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func update(cards: [LiveResizeCardSnapshot], metrics: BottomCardLayoutMetrics) {
        self.cards = cards
        self.metrics = metrics
        ensureCardLayers()
        needsLayout = true
    }

    override func layout() {
        super.layout()
        layoutCardLayers()
    }

    func ensureCardLayers() {
        while cardLayers.count < cards.count {
            let layer = LiveResizeSkeletonCardLayer()
            self.layer?.addSublayer(layer)
            cardLayers.append(layer)
        }

        if cardLayers.count > cards.count {
            for layer in cardLayers[cards.count...] {
                layer.removeFromSuperlayer()
            }
            cardLayers.removeLast(cardLayers.count - cards.count)
        }
    }

    func layoutCardLayers() {
        guard !cardLayers.isEmpty else { return }

        var x = metrics.horizontalPadding
        let y = metrics.verticalPadding

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (index, cardLayer) in cardLayers.enumerated() {
            let frame = CGRect(
                x: x,
                y: y,
                width: metrics.cardWidth,
                height: metrics.cardHeight
            ).integral
            cardLayer.frame = frame
            cardLayer.apply(snapshot: cards[index])
            x += metrics.cardWidth + metrics.spacing
        }

        CATransaction.commit()
    }
}

final class LiveResizeSkeletonCardLayer: CALayer {
    let badgeLayer = CAShapeLayer()
    let pillLayer = CAShapeLayer()
    let titleLineLayer = CAShapeLayer()
    let bodyLineLayer = CAShapeLayer()
    let footerLineLayer = CAShapeLayer()

    override init() {
        super.init()
        cornerRadius = QuickPanelBottomTheme.cardCornerRadius
        borderWidth = 1
        masksToBounds = true
        shadowOpacity = 0

        [badgeLayer, pillLayer, titleLineLayer, bodyLineLayer, footerLineLayer].forEach {
            $0.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
            addSublayer($0)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func apply(snapshot: LiveResizeCardSnapshot) {
        let normalFill = NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.11, alpha: 1)
        let selectedFill = NSColor(calibratedRed: 0.11, green: 0.15, blue: 0.22, alpha: 1)
        let normalStroke = NSColor.white.withAlphaComponent(0.05)
        let selectedStroke = NSColor(calibratedRed: 0.36, green: 0.61, blue: 0.99, alpha: 0.48)

        backgroundColor = (snapshot.isSelected ? selectedFill : normalFill).cgColor
        borderColor = (snapshot.isSelected ? selectedStroke : normalStroke).cgColor

        let accentOpacity = snapshot.isSelected ? 0.16 : 0.08
        badgeLayer.fillColor = NSColor.white.withAlphaComponent(accentOpacity).cgColor
        pillLayer.fillColor = NSColor.white.withAlphaComponent(0.08).cgColor
        titleLineLayer.fillColor = NSColor.white.withAlphaComponent(0.12).cgColor
        bodyLineLayer.fillColor = NSColor.white.withAlphaComponent(0.07).cgColor
        footerLineLayer.fillColor = NSColor.white.withAlphaComponent(0.05).cgColor
        setNeedsLayout()
    }

    override func layoutSublayers() {
        super.layoutSublayers()

        let badgeRect = CGRect(x: 12, y: 12, width: 30, height: 30)
        badgeLayer.path = CGPath(
            roundedRect: badgeRect,
            cornerWidth: 10,
            cornerHeight: 10,
            transform: nil
        )

        let pillRect = CGRect(x: bounds.width - 46, y: 22, width: 34, height: 10)
        pillLayer.path = CGPath(
            roundedRect: pillRect,
            cornerWidth: 5,
            cornerHeight: 5,
            transform: nil
        )

        let titleWidth = min(bounds.width * 0.58, 104)
        let titleRect = CGRect(x: 12, y: bounds.height - 42, width: titleWidth, height: 10)
        titleLineLayer.path = CGPath(
            roundedRect: titleRect,
            cornerWidth: 7,
            cornerHeight: 7,
            transform: nil
        )

        let bodyRect = CGRect(x: 12, y: bounds.height - 24, width: max(bounds.width - 24, 40), height: 8)
        bodyLineLayer.path = CGPath(
            roundedRect: bodyRect,
            cornerWidth: 7,
            cornerHeight: 7,
            transform: nil
        )

        let footerWidth = max(bounds.width * 0.46, 58)
        let footerRect = CGRect(x: 12, y: bounds.height - 8, width: footerWidth, height: 8)
        footerLineLayer.path = CGPath(
            roundedRect: footerRect,
            cornerWidth: 7,
            cornerHeight: 7,
            transform: nil
        )
    }
}

struct QuickPanelWindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> QuickPanelDraggableView {
        QuickPanelDraggableView()
    }

    func updateNSView(_ nsView: QuickPanelDraggableView, context: Context) {}
}

final class QuickPanelDraggableView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

struct RightClickSelector: NSViewRepresentable {
    let onSelect: () -> Void

    func makeNSView(context: Context) -> RightClickSelectorView {
        let view = RightClickSelectorView()
        view.onSelect = onSelect
        return view
    }

    func updateNSView(_ nsView: RightClickSelectorView, context: Context) {
        nsView.onSelect = onSelect
    }
}

final class RightClickSelectorView: NSView {
    var onSelect: (() -> Void)?
    
    override var isOpaque: Bool { false }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = NSApp.currentEvent, event.type == .rightMouseDown else {
            return nil
        }
        return super.hitTest(point)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        onSelect?()
        super.rightMouseDown(with: event)
    }
}


struct KeyCap: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
    }
}
