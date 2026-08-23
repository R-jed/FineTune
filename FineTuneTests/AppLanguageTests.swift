// FineTuneTests/AppLanguageTests.swift
import Foundation
import Testing
@testable import FineTune

@Suite("App language preference")
struct AppLanguageTests {
    @Test("Persistence identifiers are stable")
    func stableRawValues() {
        #expect(AppLanguage.system.rawValue == "system")
        #expect(AppLanguage.english.rawValue == "en")
        #expect(AppLanguage.simplifiedChinese.rawValue == "zh-Hans")
    }

    @Test("AppSettings defaults to Follow System")
    func defaultLanguage() {
        #expect(AppSettings().language == .system)
    }

    @Test("Older AppSettings payloads without language decode as Follow System")
    func legacyPayloadDefaultsToSystem() throws {
        let data = Data("{\"launchAtLogin\":true}".utf8)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        #expect(decoded.launchAtLogin == true)
        #expect(decoded.language == .system)
    }

    @Test("Every language choice round-trips through AppSettings Codable")
    func languageRoundTrip() throws {
        for language in AppLanguage.allCases {
            var settings = AppSettings()
            settings.language = language

            let data = try JSONEncoder().encode(settings)
            let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

            #expect(decoded.language == language)
        }
    }
}

@Suite("Localization context")
struct LocalizationContextTests {
    @Test("Follow System leaves SwiftUI locale unmodified")
    func systemHasNoOverride() {
        let context = LocalizationContext(
            language: .system,
            baseLocale: Locale(identifier: "en_AU")
        )

        #expect(context.overrideLocale == nil)
        #expect(context.presentationLocale.region?.identifier == "AU")
    }

    @Test("English override preserves the user's region")
    func englishPreservesRegion() throws {
        let context = LocalizationContext(
            language: .english,
            baseLocale: Locale(identifier: "fr_AU")
        )
        let locale = try #require(context.overrideLocale)
        let components = Locale.Components(locale: locale)

        #expect(components.languageComponents.languageCode?.identifier == "en")
        #expect(components.region?.identifier == "AU")
    }

    @Test("Simplified Chinese override preserves region and script")
    func simplifiedChinesePreservesRegionAndScript() throws {
        let context = LocalizationContext(
            language: .simplifiedChinese,
            baseLocale: Locale(identifier: "en_AU")
        )
        let locale = try #require(context.overrideLocale)
        let components = Locale.Components(locale: locale)

        #expect(components.languageComponents.languageCode?.identifier == "zh")
        #expect(components.languageComponents.script?.identifier == "Hans")
        #expect(components.region?.identifier == "AU")
    }

    @Test("Deferred resource resolves in explicit English and Simplified Chinese")
    func explicitResourceLookup() {
        let resource = LocalizedStringResource("Localization")
        let english = LocalizationContext(
            language: .english,
            baseLocale: Locale(identifier: "en_AU")
        )
        let chinese = LocalizationContext(
            language: .simplifiedChinese,
            baseLocale: Locale(identifier: "en_AU")
        )

        #expect(english.localized(resource) == "Localization")
        #expect(chinese.localized(resource) == "本地化")
    }
}
