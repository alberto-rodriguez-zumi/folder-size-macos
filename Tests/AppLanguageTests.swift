import Foundation

@main
struct AppLanguageTests {
    static func main() {
        precondition(AppLanguage.resolve("system", systemLanguages: ["es-MX"]) == "es")
        precondition(AppLanguage.resolve("system", systemLanguages: ["es_ES"]) == "es")
        precondition(AppLanguage.resolve("system", systemLanguages: ["fr-FR", "es"]) == "en")
        precondition(AppLanguage.resolve("system", systemLanguages: []) == "en")
        precondition(AppLanguage.resolve("en", systemLanguages: ["es-ES"]) == "en")
        precondition(AppLanguage.resolve("es", systemLanguages: ["en-US"]) == "es")
        print("Language resolution passed")
    }
}
