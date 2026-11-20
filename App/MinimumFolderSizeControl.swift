import SwiftUI

struct MinimumFolderSizeControl: View {
    @Binding var isEnabled: Bool
    @Binding var minimumMB: Double
    @State private var draftMB: Double

    init(isEnabled: Binding<Bool>, minimumMB: Binding<Double>) {
        self._isEnabled = isEnabled
        self._minimumMB = minimumMB
        self._draftMB = State(initialValue: minimumMB.wrappedValue)
    }

    var body: some View {
        HStack {
            Toggle("Ocultar carpetas menores de", isOn: $isEnabled)
            TextField("MB", value: $draftMB, format: .number)
                .frame(width: 60)
                .disabled(!isEnabled)
            Text("MB")
        }
        .task(id: draftMB) {
            let value = draftMB
            do {
                try await Task.sleep(for: .seconds(1))
                try Task.checkCancellation()
                if minimumMB != value {
                    minimumMB = value
                }
            } catch {
                // A new edit cancels the previous delay.
            }
        }
    }
}
