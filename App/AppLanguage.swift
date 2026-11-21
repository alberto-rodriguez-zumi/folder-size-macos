import Foundation

/// The persisted choice is a language code, so new translations can be added
/// without changing the representation stored in user defaults.
enum AppLanguage {
    static let preferenceKey = "preferredLanguage"
    static let automatic = "system"
    static let supported = ["en", "es"]

    static func resolve(_ preference: String, systemLanguages: [String]) -> String {
        if preference != automatic, supported.contains(preference) { return preference }
        guard let first = systemLanguages.first else { return "en" }
        let language = first.replacingOccurrences(of: "_", with: "-")
            .split(separator: "-").first.map(String.init)?.lowercased() ?? ""
        return supported.contains(language) ? language : "en"
    }
}

func L(_ key: String) -> String {
    let preference = UserDefaults.standard.string(forKey: AppLanguage.preferenceKey) ?? AppLanguage.automatic
    let language = AppLanguage.resolve(preference, systemLanguages: Locale.preferredLanguages)
    guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
          let bundle = Bundle(path: path) else { return key }
    return bundle.localizedString(forKey: key, value: key, table: nil)
}

func LF(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), locale: Locale.current, arguments: arguments)
}
