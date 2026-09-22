import Foundation

enum Localization {
    static let languages = ["en", "zh-Hans", "hi", "es", "ar", "fr", "bn", "pt", "id", "ur", "ru"]
    static let names = ["English", "简体中文", "हिन्दी", "Español", "العربية", "Français", "বাংলা", "Português", "Bahasa Indonesia", "اردو", "Русский"]
    static func resolved(_ selection: String) -> String {
        if languages.contains(selection) { return selection }
        return Bundle.preferredLocalizations(from: languages, forPreferences: Locale.preferredLanguages).first ?? "en"
    }
    static func text(_ key: String, language: String) -> String {
        let code = resolved(language)
        let bundle = Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        return bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }
    static func difference(_ seconds: Int, language: String) -> String {
        let minutes = abs(seconds) / 60
        let locale = Locale(identifier: resolved(language))
        let h = (minutes / 60).formatted(.number.locale(locale))
        let m = (minutes % 60).formatted(.number.locale(locale))
        let sign = seconds == 0 ? "" : seconds > 0 ? "+" : "−"
        let value = minutes % 60 == 0 ? "\(sign)\(h) \(text("h", language: language))" : "\(sign)\(h) \(text("h", language: language)) \(m) \(text("min", language: language))"
        // Isolate signed numbers and Latin units from the surrounding RTL sentence.
        return "\u{2068}\(value)\u{2069}"
    }
    static func utc(_ seconds: Int) -> String {
        String(format: "UTC%@%02d:%02d", seconds < 0 ? "−" : "+", abs(seconds) / 3600, abs(seconds) % 3600 / 60)
    }
}
