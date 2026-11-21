import SwiftUI

struct ResizableSidebar<Sidebar: View, Content: View>: View {
    @AppStorage(AppLanguage.preferenceKey) private var preferredLanguage = AppLanguage.automatic
    @Binding var sidebarWidth: CGFloat
    let isVisible: Bool
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let content: () -> Content

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
            let width = isVisible ? initialWidth : 0
            let minimumWidth = clampedWidth(0, available: geometry.size.width)
            let maximumWidth = clampedWidth(.greatestFiniteMagnitude, available: geometry.size.width)
            HStack(spacing: 0) {
                sidebar().frame(width: width).clipped().accessibilityHidden(!isVisible)
                if isVisible {
                    SplitHandle(orientation: .vertical, dragRange: (minimumWidth - initialWidth)...(maximumWidth - initialWidth)) { offset in
                        sidebarWidth = clampedWidth(initialWidth + offset, available: geometry.size.width)
                    }
                        .frame(width: dividerWidth)
                        .zIndex(1)
                        .accessibilityElement()
                        .accessibilityLabel(L("Cambiar ancho del árbol"))
                        .accessibilityAdjustableAction { direction in
                            switch direction {
                            case .increment: sidebarWidth = clampedWidth(initialWidth + 30, available: geometry.size.width)
                            case .decrement: sidebarWidth = clampedWidth(initialWidth - 30, available: geometry.size.width)
                            @unknown default: break
                            }
                        }
                        .help(L("Arrastra para cambiar el ancho del árbol"))
                }
                content().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
