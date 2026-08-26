// FineTune/Utilities/HUDPresentation.swift
import Foundation

/// FineTune-owned HUD copy. Dynamic device and app names remain verbatim while
/// static presentation resolves through the selected app language at String-only boundaries.
nonisolated enum HUDPresentation {
    static var unknownDevice: LocalizedStringResource {
        LocalizedStringResource("hud.unknownDevice", defaultValue: "Unknown device")
    }

    static var muted: LocalizedStringResource {
        LocalizedStringResource("hud.muted", defaultValue: "Muted")
    }

    static var unmuted: LocalizedStringResource {
        LocalizedStringResource("hud.unmuted", defaultValue: "Unmuted")
    }

    static var notControlled: LocalizedStringResource {
        LocalizedStringResource("hud.notControlled", defaultValue: "Not controlled by FineTune")
    }

    static var appNotControlledFallback: LocalizedStringResource {
        LocalizedStringResource(
            "hud.appNotControlledFallback",
            defaultValue: "FineTune isn't controlling this app yet"
        )
    }

    static func deviceAnnouncement(
        deviceName: String,
        sliderFraction: Double,
        mute: Bool,
        language: AppLanguage,
        baseLocale: Locale = .autoupdatingCurrent
    ) -> String {
        let localization = LocalizationContext(language: language, baseLocale: baseLocale)
        let subject = deviceName.isEmpty ? localization.localized(unknownDevice) : deviceName
        if mute {
            return subject + localization.localized(
                LocalizedStringResource("hud.accessibility.mutedSuffix", defaultValue: ", muted")
            )
        }
        return volumeAnnouncement(
            subject: subject,
            sliderFraction: sliderFraction,
            localization: localization
        )
    }

    static func tahoeAccessibilityLabel(
        deviceName: String,
        sliderFraction: Double,
        mute: Bool,
        language: AppLanguage,
        baseLocale: Locale = .autoupdatingCurrent
    ) -> String {
        let localization = LocalizationContext(language: language, baseLocale: baseLocale)
        let subject = deviceName.isEmpty ? localization.localized(unknownDevice) : deviceName
        let percent = percentage(sliderFraction)
        if mute {
            return subject
                + localization.localized(
                    LocalizedStringResource(
                        "hud.accessibility.mutedVolumePrefix",
                        defaultValue: ", muted, volume at "
                    )
                )
                + "\(percent)"
                + percentSuffix(localization: localization)
        }
        return volumeAnnouncement(
            subject: subject,
            sliderFraction: sliderFraction,
            localization: localization
        )
    }

    static func classicAccessibilityLabel(
        sliderFraction: Double,
        mute: Bool,
        language: AppLanguage,
        baseLocale: Locale = .autoupdatingCurrent
    ) -> String {
        let localization = LocalizationContext(language: language, baseLocale: baseLocale)
        if mute {
            return localization.localized(muted)
        }
        return localization.localized(
            LocalizedStringResource(
                "hud.accessibility.classicVolumePrefix",
                defaultValue: "Volume "
            )
        )
            + "\(percentage(sliderFraction))"
            + percentSuffix(localization: localization)
    }

    static func perAppVolumeAnnouncement(
        title: String,
        sliderFraction: Double,
        language: AppLanguage,
        baseLocale: Locale = .autoupdatingCurrent
    ) -> String {
        volumeAnnouncement(
            subject: title,
            sliderFraction: sliderFraction,
            localization: LocalizationContext(language: language, baseLocale: baseLocale)
        )
    }

    static func perAppMuteAnnouncement(
        title: String,
        isMuted: Bool,
        language: AppLanguage,
        baseLocale: Locale = .autoupdatingCurrent
    ) -> String {
        let localization = LocalizationContext(language: language, baseLocale: baseLocale)
        let suffix = isMuted
            ? LocalizedStringResource("hud.accessibility.mutedSuffix", defaultValue: ", muted")
            : LocalizedStringResource("hud.accessibility.unmutedSuffix", defaultValue: ", unmuted")
        return title + localization.localized(suffix)
    }

    static func perAppNotControlledAnnouncement(
        title: String,
        language: AppLanguage,
        baseLocale: Locale = .autoupdatingCurrent
    ) -> String {
        let localization = LocalizationContext(language: language, baseLocale: baseLocale)
        return title + localization.localized(
            LocalizedStringResource(
                "hud.accessibility.notControlledSuffix",
                defaultValue: ", not controlled by FineTune"
            )
        )
    }

    static func localizedAppNotControlledFallback(
        language: AppLanguage,
        baseLocale: Locale = .autoupdatingCurrent
    ) -> String {
        LocalizationContext(language: language, baseLocale: baseLocale)
            .localized(appNotControlledFallback)
    }

    private static func volumeAnnouncement(
        subject: String,
        sliderFraction: Double,
        localization: LocalizationContext
    ) -> String {
        subject
            + localization.localized(
                LocalizedStringResource(
                    "hud.accessibility.volumePrefix",
                    defaultValue: ", volume "
                )
            )
            + "\(percentage(sliderFraction))"
            + percentSuffix(localization: localization)
    }

    private static func percentSuffix(localization: LocalizationContext) -> String {
        localization.localized(
            LocalizedStringResource(
                "hud.accessibility.percentSuffix",
                defaultValue: " percent"
            )
        )
    }

    private static func percentage(_ sliderFraction: Double) -> Int {
        Int((max(0, min(1, sliderFraction)) * 100).rounded())
    }
}
