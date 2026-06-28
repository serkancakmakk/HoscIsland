import Foundation

/// UI language. `system` follows the OS locale; otherwise forced TR/EN.
enum AppLanguage: String, CaseIterable {
    case system
    case turkish
    case english

    var label: String {
        switch self {
        case .system: return L("Sistem", "System")
        case .turkish: return "Türkçe"
        case .english: return "English"
        }
    }
}

/// Whether the UI should render in English right now.
var isEnglishUI: Bool {
    switch Settings.shared.language {
    case .english: return true
    case .turkish: return false
    case .system:
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return code != "tr"
    }
}

/// Pick the Turkish or English string for the current UI language. Call sites
/// pass both, so there's no key table to keep in sync: `L("Temizle", "Clear")`.
func L(_ tr: String, _ en: String) -> String {
    isEnglishUI ? en : tr
}
