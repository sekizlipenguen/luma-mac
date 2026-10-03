import Foundation

/// In-app language preference. Turkish is first among explicit languages.
/// Only widely used languages — not an exhaustive catalog.
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable, Codable {
    case system
    case tr
    case en
    case de
    case fr
    case es
    case it
    case ptBR = "pt-BR"
    case ja
    case ko
    case zhHans = "zh-Hans"
    case ru
    case ar

    public var id: String { rawValue }

    /// Native endonym for the picker (always shown in that language’s own script).
    public var nativeName: String {
        switch self {
        case .system: LumaL10n.string("System Default")
        case .tr: "Türkçe"
        case .en: "English"
        case .de: "Deutsch"
        case .fr: "Français"
        case .es: "Español"
        case .it: "Italiano"
        case .ptBR: "Português (Brasil)"
        case .ja: "日本語"
        case .ko: "한국어"
        case .zhHans: "简体中文"
        case .ru: "Русский"
        case .ar: "العربية"
        }
    }

    public var locale: Locale {
        switch self {
        case .system: .autoupdatingCurrent
        default: Locale(identifier: rawValue)
        }
    }

    /// BCP-47 tag used for String Catalog / AppleLanguages / `.lproj`.
    public var localizationIdentifier: String? {
        switch self {
        case .system: nil
        default: rawValue
        }
    }

    public static let storageKey = "luma.languageCode"

    /// Resolves a stored code; unknown / removed languages fall back to system.
    public static func resolved(code: String?) -> AppLanguage {
        guard let code, let language = AppLanguage(rawValue: code) else { return .system }
        return language
    }

    public static var current: AppLanguage {
        resolved(code: UserDefaults.standard.string(forKey: storageKey))
    }

    public static var preferredLocale: Locale { current.locale }

    /// Keeps Foundation / ByteCountFormatter / Bundle lookups aligned with the in-app language.
    /// SwiftUI `environment(\.locale)` alone is not enough for `String(localized:)` / formatters.
    public static func applyBundleLanguagePreference() {
        let language = current
        if let id = language.localizationIdentifier {
            UserDefaults.standard.set([id], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }
}

/// Resolves UI copy against the in-app language override (not only system locale).
/// Strings live in the app target’s `Localizable.xcstrings` (compiled to `*.lproj/Localizable.strings`).
public enum LumaL10n {
    public static func string(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: localizationBundle(), locale: AppLanguage.preferredLocale)
    }

    public static func string(_ key: String) -> String {
        localizationBundle().localizedString(forKey: key, value: key, table: "Localizable")
    }

    public static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let format = string(key)
        return String(format: format, locale: AppLanguage.preferredLocale, arguments: arguments)
    }

    public static func itemCountLabel(_ count: Int) -> String {
        let word = string(count == 1 ? "item" : "items")
        return format("%lld %@", Int64(count), word)
    }

    /// Prefer the explicit language `.lproj` so lookups never fall back to development English
    /// when `Bundle.main.preferredLocalizations` is still stale.
    private static func localizationBundle() -> Bundle {
        if let id = AppLanguage.current.localizationIdentifier,
           let path = Bundle.main.path(forResource: id, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }
}
