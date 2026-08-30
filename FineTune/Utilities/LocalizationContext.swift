// FineTune/Utilities/LocalizationContext.swift
import Foundation
import SwiftUI

/// Resolves FineTune-owned presentation to one of its two supported UI languages
/// while preserving the user's regional formatting preferences.
nonisolated struct LocalizationContext: Sendable {
    let language: AppLanguage
    let baseLocale: Locale
    private let resolvedLanguageIdentifier: String

    init(
        language: AppLanguage,
        baseLocale: Locale = .autoupdatingCurrent,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) {
        self.language = language
        self.baseLocale = baseLocale
        self.resolvedLanguageIdentifier = language.resolvedLanguageIdentifier(
            preferredLanguages: preferredLanguages
        )
    }

    /// FineTune-owned UI always resolves to English or Simplified Chinese.
    /// The region remains the user's current region for date and number formatting.
    var overrideLocale: Locale {
        var components = Locale.Components(locale: baseLocale)
        components.languageComponents = Locale.Language.Components(
            identifier: resolvedLanguageIdentifier
        )
        components.region = baseLocale.region
        return Locale(components: components)
    }

    var presentationLocale: Locale {
        overrideLocale
    }

    /// Resolves a deferred localizable resource at the final String boundary.
    func localized(_ resource: LocalizedStringResource) -> String {
        var localizedResource = resource
        localizedResource.locale = overrideLocale
        return String(localized: localizedResource)
    }
}

private struct FineTuneLocaleModifier: ViewModifier {
    let locale: Locale

    func body(content: Content) -> some View {
        content.environment(\.locale, locale)
    }
}

extension View {
    /// Applies FineTune's resolved runtime UI locale.
    func fineTuneLocale(_ locale: Locale) -> some View {
        modifier(FineTuneLocaleModifier(locale: locale))
    }
}
