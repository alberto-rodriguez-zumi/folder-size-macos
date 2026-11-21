import SwiftUI

struct LanguageSettingsView: View {
    @AppStorage(AppLanguage.preferenceKey) private var language = AppLanguage.automatic

    var body: some View {
        Form {
            Picker(selection: $language) {
                Text(L("Automático (idioma del sistema)")).tag(AppLanguage.automatic)
                Text(verbatim: "Español").tag("es")
                Text(verbatim: "English").tag("en")
                Text(verbatim: "日本語").tag("ja")
            } label: {
                Label(L("Idioma"), systemImage: "globe")
            }
        }
        .navigationTitle(L("Configuración"))
        .formStyle(.grouped)
        .frame(width: 420, height: 150)
    }
}

struct LocalizedContent<Content: View>: View {
    @AppStorage(AppLanguage.preferenceKey) private var language = AppLanguage.automatic
    @ViewBuilder let content: () -> Content

    var body: some View {
        content().environment(\.locale, Locale(identifier: AppLanguage.resolve(language, systemLanguages: Locale.preferredLanguages)))
    }
}
