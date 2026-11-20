import SwiftUI

struct ResizableSidebar<Sidebar: View, Content: View>: View {
    @Binding var sidebarWidth: CGFloat
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let content: () -> Content
    @GestureState private var dragOffset: CGFloat = 0

    private let dividerWidth: CGFloat = 12
    private let minimumSidebarWidth: CGFloat = 170

    private func clampedWidth(_ proposed: CGFloat, available: CGFloat) -> CGFloat {
        let maximum = max(0, (available - dividerWidth) / 2)
        let minimum = min(minimumSidebarWidth, maximum)
        return min(max(proposed, minimum), maximum)
    }

    var body: some View {
        GeometryReader { geometry in
            let initialWidth = clampedWidth(sidebarWidth, available: geometry.size.width)
            let width = clampedWidth(initialWidth + dragOffset, available: geometry.size.width)
            HStack(spacing: 0) {
                sidebar().frame(width: width)
                SplitHandle(orientation: .vertical)
                    .frame(width: dividerWidth)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .updating($dragOffset) { value, offset, _ in
                                offset = value.translation.width
                            }
                            .onEnded { value in
                                sidebarWidth = clampedWidth(initialWidth + value.translation.width, available: geometry.size.width)
                            }
                    )
                    .accessibilityElement()
                    .accessibilityLabel("Cambiar ancho del árbol")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: sidebarWidth = clampedWidth(initialWidth + 30, available: geometry.size.width)
                        case .decrement: sidebarWidth = clampedWidth(initialWidth - 30, available: geometry.size.width)
                        @unknown default: break
                        }
                    }
                    .help("Arrastra para cambiar el ancho del árbol")
                content().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
