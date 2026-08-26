// FineTune/Settings/Types/AppLanguage.swift
import Foundation

/// User-selected language policy for FineTune-owned interface text.
/// Raw values are persistence identifiers and must remain stable.
nonisolated enum AppLanguage: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    /// Resolves every preference to one of FineTune's two supported UI languages.
    /// Auto uses the first preferred system language. Any Chinese locale maps to
    /// Simplified Chinese; every other or missing value maps to English.
    func resolvedLanguageIdentifier(
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        switch self {
        case .system:
            guard let preferredLanguage = preferredLanguages.first else {
                return "en"
            }
            let normalized = preferredLanguage
                .replacingOccurrences(of: "_", with: "-")
                .lowercased()
            return normalized == "zh" || normalized.hasPrefix("zh-")
                ? "zh-Hans"
                : "en"
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        }
    }

    var displayName: LocalizedStringResource {
        switch self {
        case .system: "Auto"
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }
}
