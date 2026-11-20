import SwiftUI

struct ResizableResults<Chart: View, Results: View>: View {
    @ViewBuilder let chart: () -> Chart
    @ViewBuilder let list: () -> Results

    @State private var listHeight: CGFloat = 140

    private let dividerHeight: CGFloat = 12
    private let minimumListHeight: CGFloat = 70
    private let minimumChartHeight: CGFloat = 160

    private func clampedHeight(_ proposed: CGFloat, available: CGFloat) -> CGFloat {
        let maximum = max(minimumListHeight, available - dividerHeight - minimumChartHeight)
        return min(max(proposed, minimumListHeight), maximum)
    }

    var body: some View {
        GeometryReader { geometry in
            let startingHeight = clampedHeight(listHeight, available: geometry.size.height)
            let height = startingHeight
            let maximumHeight = clampedHeight(.greatestFiniteMagnitude, available: geometry.size.height)
            VStack(spacing: 0) {
                chart()
                    .frame(height: max(0, geometry.size.height - height - dividerHeight))
                SplitHandle(orientation: .horizontal, dragRange: (startingHeight - maximumHeight)...(startingHeight - minimumListHeight)) { offset in
                    listHeight = clampedHeight(startingHeight - offset, available: geometry.size.height)
                }
                    .frame(height: dividerHeight)
                    .zIndex(1)
                    .accessibilityElement()
                    .accessibilityLabel("Cambiar tamaño de la lista")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: listHeight = clampedHeight(listHeight + 30, available: geometry.size.height)
                        case .decrement: listHeight = clampedHeight(listHeight - 30, available: geometry.size.height)
                        @unknown default: break
                        }
                    }
                    .help("Arrastra para cambiar el tamaño de la lista")
                list().frame(height: height)
            }
        }
        .frame(minHeight: minimumChartHeight + minimumListHeight + dividerHeight)
    }
}
