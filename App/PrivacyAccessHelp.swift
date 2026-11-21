import SwiftUI
import AppKit

struct PrivacyAccessHelp: View {
    @AppStorage(AppLanguage.preferenceKey) private var preferredLanguage = AppLanguage.automatic
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingHelp = false
    @State private var hasFullDiskAccess = false

    var body: some View {
        Group {
            if !hasFullDiskAccess {
                helpButton
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            let hasAccess = await Task.detached(priority: .utility) {
                FullDiskAccessProbe.canOpenProtectedFile()
            }.value
            guard !Task.isCancelled else { return }
            hasFullDiskAccess = hasAccess
        }
    }

    private var helpButton: some View {
        Button {
            showingHelp = true
        } label: {
            Label(L("Acceso al disco"), systemImage: "lock.shield")
        }
        .popover(isPresented: $showingHelp, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L("Acceso completo al disco")).font(.headline)
                Text(L("Puedes permitir el acceso a Folder Size en Ajustes del Sistema para analizar más ubicaciones protegidas."))
                Text(L("En Privacidad y seguridad, abre Acceso total al disco y añade o activa Folder Size. Después vuelve a analizar la carpeta."))
                Text(L("Los permisos de archivos y carpetas de otras cuentas también pueden limitar el acceso. Las rutas omitidas aparecen en Incidencias."))
                    .foregroundStyle(.secondary)
                Button(L("Abrir Ajustes de privacidad"), systemImage: "gearshape") {
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
