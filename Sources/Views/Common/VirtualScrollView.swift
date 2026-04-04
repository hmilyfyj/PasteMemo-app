import SwiftUI

struct VirtualScrollView<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let itemHeight: CGFloat
    let spacing: CGFloat
    let content: (Item) -> Content
    
    @State private var scrollOffset: CGFloat = 0
    @State private var containerHeight: CGFloat = 0
    
    private var visibleRange: Range<Int> {
        let startIndex = max(0, Int((scrollOffset / (itemHeight + spacing)).rounded(.down)) - 5)
        let endIndex = min(items.count, Int(((scrollOffset + containerHeight) / (itemHeight + spacing)).rounded(.up)) + 5)
        return startIndex..<endIndex
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: spacing) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            if visibleRange.contains(index) {
                                content(item)
                                    .frame(height: itemHeight)
                                    .id(item.id)
                            } else {
                                Color.clear
                                    .frame(height: itemHeight)
                                    .id(item.id)
                            }
                        }
                    }
                    .padding()
                    .background(
                        ScrollOffsetReader(offset: $scrollOffset)
                    )
                }
            }
            .onAppear {
                containerHeight = geometry.size.height
            }
            .onChange(of: geometry.size.height) { _, newHeight in
                containerHeight = newHeight
            }
        }
    }
}

struct ScrollOffsetReader: NSViewRepresentable {
    @Binding var offset: CGFloat
    
    func makeNSView(context: Context) -> NSView {
        let view = ScrollOffsetNSView()
        view.onScroll = { newOffset in
            DispatchQueue.main.async {
                self.offset = newOffset
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class ScrollOffsetNSView: NSView {
    var onScroll: ((CGFloat) -> Void)?
    
    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        let offset = enclosingScrollView?.documentView?.bounds.origin.y ?? 0
        onScroll?(offset)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                if let offset = self?.enclosingScrollView?.documentView?.bounds.origin.y {
                    self?.onScroll?(offset)
                }
            }
        }
    }
}
