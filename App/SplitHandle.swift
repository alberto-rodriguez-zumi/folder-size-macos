import SwiftUI
import AppKit

struct SplitHandle: View {
    enum Orientation { case horizontal, vertical }
    let orientation: Orientation
    let dragRange: ClosedRange<CGFloat>
    let onDragEnd: (CGFloat) -> Void
    @GestureState private var dragOffset: CGFloat?
    @State private var cursorIsActive = false

    private func limited(_ value: CGFloat) -> CGFloat {
        min(max(value, dragRange.lowerBound), dragRange.upperBound)
    }

    var body: some View {
        ZStack {
            Rectangle().fill(Color(nsColor: .separatorColor))
                .frame(width: orientation == .vertical ? 1 : nil, height: orientation == .horizontal ? 1 : nil)
            Capsule().fill(Color.secondary.opacity(0.7))
                .frame(width: orientation == .horizontal ? 36 : 4, height: orientation == .horizontal ? 4 : 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .overlay {
            if let dragOffset {
                Rectangle().fill(Color.accentColor.opacity(0.8))
                    .frame(width: orientation == .vertical ? 2 : nil, height: orientation == .horizontal ? 2 : nil)
                    .offset(x: orientation == .vertical ? dragOffset : 0, y: orientation == .horizontal ? dragOffset : 0)
                    .allowsHitTesting(false)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($dragOffset) { value, offset, _ in
                    offset = limited(orientation == .horizontal ? value.translation.height : value.translation.width)
                }
                .onEnded { value in
                    onDragEnd(limited(orientation == .horizontal ? value.translation.height : value.translation.width))
                }
        )
        .onHover { inside in
            if inside && !cursorIsActive {
                (orientation == .horizontal ? NSCursor.resizeUpDown : NSCursor.resizeLeftRight).push()
                cursorIsActive = true
            } else if !inside && cursorIsActive {
                NSCursor.pop()
                cursorIsActive = false
            }
        }
        .onDisappear {
            if cursorIsActive {
                NSCursor.pop()
                cursorIsActive = false
            }
        }
    }
}
