import SwiftUI
import AppKit

struct AboutView: View {
    @AppStorage(AppLanguage.preferenceKey) private var preferredLanguage = AppLanguage.automatic
    private var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return LF("Versión %@ (%@)", version, build)
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
            Text(L("Explora el espacio ocupado por archivos y carpetas en tu Mac."))
                .multilineTextAlignment(.center)
            Link(destination: URL(string: "https://alberto-rodriguez-zumi.github.io/folder-size-macos/")!) {
                Label(L("Sitio web de Folder Size"), systemImage: "arrow.up.right.square")
            }
            .help(L("Abrir la web de Folder Size"))
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Descargo de responsabilidad")).font(.headline)
                Text(L("La aplicación se proporciona tal cual, sin garantías. Las cifras pueden ser parciales o aproximadas y no predicen necesariamente el espacio que se liberará. Revisa los archivos antes de moverlos a la papelera y mantén copias de seguridad. En la medida permitida por la ley, sus autores no se responsabilizan de pérdidas o daños derivados de su uso."))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(28)
        .frame(width: 460)
    }
}
