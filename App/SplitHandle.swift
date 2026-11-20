import SwiftUI
import AppKit

struct SplitHandle: View {
    enum Orientation { case horizontal, vertical }
    let orientation: Orientation

    var body: some View {
        ZStack {
            Rectangle().fill(Color(nsColor: .separatorColor))
                .frame(width: orientation == .vertical ? 1 : nil, height: orientation == .horizontal ? 1 : nil)
            Capsule().fill(Color.secondary.opacity(0.7))
                .frame(width: orientation == .horizontal ? 36 : 4, height: orientation == .horizontal ? 4 : 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .background(ResizeCursor(orientation: orientation).allowsHitTesting(false))
    }
}

private struct ResizeCursor: NSViewRepresentable {
    let orientation: SplitHandle.Orientation

    func makeNSView(context: Context) -> CursorView {
        let view = CursorView()
        view.cursor = orientation == .horizontal ? .resizeUpDown : .resizeLeftRight
        return view
    }

    func updateNSView(_ view: CursorView, context: Context) {
        view.cursor = orientation == .horizontal ? .resizeUpDown : .resizeLeftRight
        view.window?.invalidateCursorRects(for: view)
    }

    final class CursorView: NSView {
        var cursor: NSCursor = .arrow

        override func resetCursorRects() {
            super.resetCursorRects()
            addCursorRect(bounds, cursor: cursor)
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
