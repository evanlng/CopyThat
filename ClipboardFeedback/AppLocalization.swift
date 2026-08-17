import Foundation

enum InterfaceLocale: String, Equatable {
    case english
    case simplifiedChinese

    static var system: InterfaceLocale {
        guard let identifier = Locale.preferredLanguages.first?.lowercased() else {
            return .english
        }
        return identifier.hasPrefix("zh") ? .simplifiedChinese : .english
    }

    var locale: Locale {
        switch self {
        case .english: return Locale(identifier: "en")
        case .simplifiedChinese: return Locale(identifier: "zh-Hans")
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    var id: String { rawValue }

    var resolvedLocale: InterfaceLocale {
        switch self {
        case .system: return .system
        case .english: return .english
        case .simplifiedChinese: return .simplifiedChinese
        }
    }

    func title(in locale: InterfaceLocale) -> String {
        switch self {
        case .system:
            return L10n.text("Automatic (System)", "自动（跟随系统）", locale: locale)
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }
}

enum L10n {
    static func text(
        _ english: String,
        _ simplifiedChinese: String,
        locale: InterfaceLocale
    ) -> String {
        switch locale {
        case .english: return english
        case .simplifiedChinese: return simplifiedChinese
        }
    }
}
