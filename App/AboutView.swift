import SwiftUI
import AppKit

struct AboutView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "Versión \(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable().interpolation(.high).frame(width: 88, height: 88)
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text("Folder Size").font(.title2.weight(.semibold))
                Text(version).foregroundStyle(.secondary)
            }
            Text("Explora el espacio ocupado por archivos y carpetas en tu Mac.")
                .multilineTextAlignment(.center)
            Link(destination: URL(string: "https://github.com/alberto-rodriguez-zumi/folder-size")!) {
                Label("Repositorio en GitHub", systemImage: "arrow.up.right.square")
            }
            .help("Abrir el repositorio de Folder Size")
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Descargo de responsabilidad").font(.headline)
                Text("La aplicación se proporciona tal cual, sin garantías. Las cifras pueden ser parciales o aproximadas y no predicen necesariamente el espacio que se liberará. Revisa los archivos antes de moverlos a la papelera y mantén copias de seguridad. En la medida permitida por la ley, sus autores no se responsabilizan de pérdidas o daños derivados de su uso.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(28)
        .frame(width: 460)
    }
}
