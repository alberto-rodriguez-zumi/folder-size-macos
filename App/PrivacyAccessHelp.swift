import SwiftUI
import AppKit

struct PrivacyAccessHelp: View {
    @State private var showingHelp = false

    var body: some View {
        Button {
            showingHelp = true
        } label: {
            Label("Acceso al disco", systemImage: "lock.shield")
        }
        .popover(isPresented: $showingHelp, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Acceso completo al disco").font(.headline)
                Text("Puedes permitir el acceso a Folder Size en Ajustes del Sistema para analizar más ubicaciones protegidas.")
                Text("En Privacidad y seguridad, abre Acceso total al disco y añade o activa Folder Size. Después vuelve a analizar la carpeta.")
                Text("Los permisos de archivos y carpetas de otras cuentas también pueden limitar el acceso. Las rutas omitidas aparecen en Incidencias.")
                    .foregroundStyle(.secondary)
                Button("Abrir Ajustes de privacidad", systemImage: "gearshape") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .frame(width: 340, alignment: .leading)
            .padding(18)
        }
    }
}
