import SwiftUI

struct ScanStartView: View {
    @ObservedObject var state: ScanState
    @Binding var displayDepth: Int

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            VStack(spacing: 22) {
                if state.scanning {
                    ScanIllustration()
                } else {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(.tint)
                        .frame(width: 86, height: 86)
                        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 22))
                        .accessibilityHidden(true)
                }

                if state.scanning {
                    VStack(spacing: 8) {
                        Text("Analizando el espacio").font(.title2.weight(.semibold))
                        Text("\(state.scannedItems.formatted()) elementos examinados")
                            .foregroundStyle(.secondary)
                    }
                    ProgressView().progressViewStyle(.linear).frame(maxWidth: 380)
                    ScrollView(.vertical) {
                        Text(state.progress)
                            .font(.caption).foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: 480)
                    .frame(height: 56)
                    Button("Cancelar", systemImage: "xmark", action: state.cancel).keyboardShortcut(.cancelAction)
                } else {
                    VStack(spacing: 8) {
                        Text("Explora tu espacio").font(.title2.weight(.semibold))
                        Text("Elige una carpeta o volumen para ver qué ocupa más.")
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Detalle del análisis").font(.headline)
                            Picker("Detalle del análisis", selection: $state.fullDetail) {
                                Text("Bajo demanda").tag(false)
                                Text("Completo").tag(true)
                            }
                            .pickerStyle(.segmented).labelsHidden()
                            Text(state.fullDetail ? "Guarda todos los niveles para explorarlos. Requiere más memoria." : "Carga los niveles profundos al abrirlos. Usa menos memoria.")
                                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Divider()
                        Toggle(isOn: $state.includeHiddenFolders) {
                            Label("Analizar carpetas ocultas", systemImage: "eye.slash")
                        }
                        HStack {
                            Label("Niveles en los gráficos", systemImage: "square.stack.3d.up")
                            Spacer()
                            Picker("Niveles en los gráficos", selection: $displayDepth) {
                                ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                            }.labelsHidden().frame(width: 65)
                        }
                        Text("La profundidad de los gráficos no limita el cálculo del espacio.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .frame(maxWidth: 460, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                    Button(action: state.choose) {
                        Label("Elegir carpeta o volumen", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    PrivacyAccessHelp()
                }
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 20)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
