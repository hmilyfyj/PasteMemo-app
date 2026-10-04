import AppKit
import SwiftUI
import Testing
@testable import PasteMemo

@Suite("Horizontal mouse wheel scrolling")
@MainActor
struct HorizontalMouseWheelScrollTests {
    private func wheel(x: Int32 = 0, y: Int32, precise: Bool = false) throws -> NSEvent {
        let cg = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .line,
                                     wheelCount: 2, wheel1: y, wheel2: x, wheel3: 0))
        cg.setIntegerValueField(.scrollWheelEventIsContinuous, value: precise ? 1 : 0)
        cg.flags = .maskAlternate
        return try #require(NSEvent(cgEvent: cg))
    }

    private func scrollView(documentWidth: CGFloat = 1200) -> NSScrollView {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 240, height: 100))
        scroll.documentView = NSView(frame: NSRect(x: 0, y: 0, width: documentWidth, height: 100))
        scroll.horizontalLineScroll = 12
        return scroll
    }

    @Test("native line speed and precise smoothing events scroll by their own units", arguments: [false, true])
    func scrollDistance(precise: Bool) throws {
        let scroll = scrollView()
        let event = try wheel(y: -3, precise: precise)
        #expect(HorizontalMouseWheelScroll.scroll(event, in: scroll))
        let expected = -event.scrollingDeltaY * (precise ? 1 : scroll.horizontalLineScroll)
        #expect(scroll.contentView.bounds.minX == expected)
        #expect(scroll.contentView.bounds.minY == 0)
        #expect(event.scrollingDeltaX == 0)
        #expect(event.modifierFlags.contains(.option))
    }

    @Test("horizontal and diagonal gestures and empty events pass through")
    func leavesNativeAxesAlone() throws {
        let scroll = scrollView()
        for event in [try wheel(x: -3, y: 0, precise: true),
                      try wheel(x: -3, y: -2, precise: true),
                      try wheel(x: -3, y: 0),
                      try wheel(x: -3, y: -2),
                      try wheel(y: 0)] {
            #expect(!HorizontalMouseWheelScroll.scroll(event, in: scroll))
            #expect(scroll.contentView.bounds.minX == 0)
        }
    }

    @Test("native scroll view moves right on wheel down and clamps both edges")
    func scrollsNativeContainer() throws {
        let scroll = scrollView()
        #expect(HorizontalMouseWheelScroll.scroll(try wheel(y: -3), in: scroll))
        #expect(scroll.contentView.bounds.minX > 0)
        #expect(scroll.contentView.bounds.minY == 0)
        #expect(HorizontalMouseWheelScroll.scroll(try wheel(y: 1000), in: scroll))
        #expect(scroll.contentView.bounds.minX == 0)
        #expect(HorizontalMouseWheelScroll.scroll(try wheel(y: -1000), in: scroll))
        let maximum = try #require(scroll.documentView).bounds.width - scroll.contentView.bounds.width
        #expect(scroll.contentView.bounds.minX <= maximum)
        #expect(scroll.contentView.bounds.minX > 0)
    }

    @Test("short content does not consume the wheel")
    func shortContentPassesThrough() throws {
        let scroll = scrollView(documentWidth: 120)
        #expect(!HorizontalMouseWheelScroll.scroll(try wheel(y: -3), in: scroll))
        #expect(scroll.contentView.bounds.minX == 0)
    }

    @Test("SwiftUI content marker finds the scroll container without intercepting clicks")
    func attachesToSwiftUIScrollView() throws {
        let content = ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack {
                ForEach(0..<20) { _ in Color.blue.frame(width: 140, height: 100) }
            }
            .background(HorizontalMouseWheelScrollBridge())
        }
        let host = NSHostingView(rootView: content)
        let window = NSWindow(contentRect: NSRect(x: -10000, y: 0, width: 300, height: 140),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        for _ in 0..<3 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            host.layoutSubtreeIfNeeded()
        }
        func marker(in view: NSView) -> HorizontalMouseWheelScrollBridge.MarkerView? {
            if let marker = view as? HorizontalMouseWheelScrollBridge.MarkerView { return marker }
            return view.subviews.lazy.compactMap { marker(in: $0) }.first
        }
        let marker = try #require(marker(in: host))
        let scroll = try #require(marker.enclosingScrollView)
        #expect(marker.hitTest(.zero) == nil)
        let hit = try #require(host.hitTest(NSPoint(x: 150, y: 70)))
        #expect(hit === scroll || hit.enclosingScrollView === scroll)
        #expect(HorizontalMouseWheelScroll.scroll(try wheel(y: -3), in: scroll))
        #expect(scroll.contentView.bounds.minX > 0)
    }
}
