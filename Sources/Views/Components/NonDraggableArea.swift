import SwiftUI
import AppKit

/// 把内容包进一层 `mouseDownCanMoveWindow = false` 的 hosting view。
///
/// 快捷面板开启了 `isMovableByWindowBackground`（空白处随手拖动）。SwiftUI 的按钮
/// 是手势实现，AppKit 命中测试拿到的是 hosting view 本身——它默认参与背景拖拽，
/// 于是点击分类标签时窗口跟着微拖「晃动」。放进本容器的区域不参与背景拖拽，
/// 按钮点击不受影响。
struct NonDraggableArea<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSView(context: Context) -> NSHostingView<Content> {
        NonDraggingHostingView(rootView: content)
    }

    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {
        nsView.rootView = content
    }
}

private final class NonDraggingHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { false }
}
