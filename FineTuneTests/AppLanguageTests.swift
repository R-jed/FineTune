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

    @Test("AppSettings defaults to Auto")
    func defaultLanguage() {
        #expect(AppSettings().language == .system)
    }

    @Test("Older AppSettings payloads without language decode as Auto")
    func legacyPayloadDefaultsToAuto() throws {
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

    @Test("Auto maps only the first preferred system language")
    func autoLanguageMapping() {
        let cases: [([String], String)] = [
            (["zh-Hans-CN"], "zh-Hans"),
            (["zh-Hant-TW"], "zh-Hans"),
            (["zh_CN"], "zh-Hans"),
            (["zh"], "zh-Hans"),
            (["en-AU"], "en"),
            (["ja-JP"], "en"),
            (["fr-FR"], "en"),
            (["ja-JP", "zh-Hans-CN"], "en"),
            ([""], "en"),
            ([], "en")
        ]

        for (preferredLanguages, expected) in cases {
            #expect(
                AppLanguage.system.resolvedLanguageIdentifier(
                    preferredLanguages: preferredLanguages
                ) == expected
            )
        }
    }

    @Test("Explicit languages ignore system preference")
    func explicitLanguagesIgnoreSystemPreference() {
        #expect(
            AppLanguage.english.resolvedLanguageIdentifier(
                preferredLanguages: ["zh-Hant-TW"]
            ) == "en"
        )
        #expect(
            AppLanguage.simplifiedChinese.resolvedLanguageIdentifier(
                preferredLanguages: ["ja-JP"]
            ) == "zh-Hans"
        )
    }
}

@Suite("Localization context")
struct LocalizationContextTests {
    @Test("Auto resolves Chinese system preference to Simplified Chinese")
    func autoChinese() {
        let context = LocalizationContext(
            language: .system,
            baseLocale: Locale(identifier: "en_AU"),
            preferredLanguages: ["zh-Hant-TW"]
        )
        let components = Locale.Components(locale: context.overrideLocale)

        #expect(components.languageComponents.languageCode?.identifier == "zh")
        #expect(components.languageComponents.script?.identifier == "Hans")
        #expect(components.region?.identifier == "AU")
        #expect(context.localized("Localization") == "本地化")
    }

    @Test("Auto maps unsupported system languages to English")
    func autoUnsupportedLanguageFallsBackToEnglish() {
        let context = LocalizationContext(
            language: .system,
            baseLocale: Locale(identifier: "fr_FR"),
            preferredLanguages: ["ja-JP"]
        )
        let components = Locale.Components(locale: context.overrideLocale)

        #expect(components.languageComponents.languageCode?.identifier == "en")
        #expect(components.region?.identifier == "FR")
        #expect(context.localized("Localization") == "Localization")
    }

    @Test("Auto maps missing system language data to English")
    func autoMissingLanguageFallsBackToEnglish() {
        let context = LocalizationContext(
            language: .system,
            baseLocale: Locale(identifier: "zh_Hans_CN"),
            preferredLanguages: []
        )
        let components = Locale.Components(locale: context.overrideLocale)

        #expect(components.languageComponents.languageCode?.identifier == "en")
        #expect(components.region?.identifier == "CN")
    }

    @Test("Explicit English remains English")
    func explicitEnglish() {
        let context = LocalizationContext(
            language: .english,
            baseLocale: Locale(identifier: "zh_Hans_CN"),
            preferredLanguages: ["zh-Hans-CN"]
        )
        let components = Locale.Components(locale: context.overrideLocale)

        #expect(components.languageComponents.languageCode?.identifier == "en")
        #expect(components.region?.identifier == "CN")
    }

    @Test("Explicit Simplified Chinese remains Simplified Chinese")
    func explicitSimplifiedChinese() {
        let context = LocalizationContext(
            language: .simplifiedChinese,
            baseLocale: Locale(identifier: "en_AU"),
            preferredLanguages: ["ja-JP"]
        )
        let components = Locale.Components(locale: context.overrideLocale)

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
