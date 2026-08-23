// FineTune/Settings/Types/AppLanguage.swift
import Foundation

/// User-selected language policy for FineTune-owned interface text.
/// Raw values are persistence identifiers and must remain stable.
nonisolated enum AppLanguage: String, Codable, CaseIterable, Equatable, Sendable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var languageIdentifier: String? {
        switch self {
        case .system:
            nil
        case .english:
            "en"
        case .simplifiedChinese:
            "zh-Hans"
        }
    }

    var displayName: LocalizedStringResource {
        switch self {
        case .system: "Follow System"
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }
}
