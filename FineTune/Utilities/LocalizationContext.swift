// FineTune/Utilities/LocalizationContext.swift
import Foundation
import SwiftUI

/// Resolves FineTune's optional runtime UI-language override while preserving
/// the user's regional formatting preferences.
nonisolated struct LocalizationContext: Sendable {
    let language: AppLanguage
    let baseLocale: Locale

    init(language: AppLanguage, baseLocale: Locale = .autoupdatingCurrent) {
        self.language = language
        self.baseLocale = baseLocale
    }

    /// A locale for FineTune-owned presentation when the user explicitly picks a language.
    /// `nil` means FineTune must leave SwiftUI's locale untouched so macOS can apply the
    /// app-specific language selected in System Settings.
    var overrideLocale: Locale? {
        guard let languageIdentifier = language.languageIdentifier else { return nil }

        var components = Locale.Components(locale: baseLocale)
        var languageComponents = Locale.Language.Components(identifier: languageIdentifier)
        languageComponents.region = components.region
        components.languageComponents = languageComponents
        return Locale(components: components)
    }

    /// Locale for FineTune-owned date/number formatting. Follow System uses the user's
    /// live locale; explicit language choices keep the user's region while changing language.
    var presentationLocale: Locale {
        overrideLocale ?? baseLocale
    }

    /// Resolves a deferred localizable resource at the final String boundary.
    /// Follow System deliberately uses normal bundle lookup with no FineTune override.
    func localized(_ resource: LocalizedStringResource) -> String {
        guard let locale = overrideLocale else {
            return String(localized: resource)
        }

        var localizedResource = resource
        localizedResource.locale = locale
        return String(localized: localizedResource)
    }
}

private struct FineTuneLocaleModifier: ViewModifier {
    let locale: Locale?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let locale {
            content.environment(\.locale, locale)
        } else {
            content
        }
    }
}

extension View {
    /// Applies FineTune's explicit runtime locale only when one is selected.
    func fineTuneLocale(_ locale: Locale?) -> some View {
        modifier(FineTuneLocaleModifier(locale: locale))
    }
}
