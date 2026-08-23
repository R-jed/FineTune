// FineTune/Utilities/DeviceNotificationPresentation.swift
import Foundation

/// FineTune-owned notification copy resolved at the final String boundary.
/// Device names remain verbatim while static copy follows the selected app language.
nonisolated struct DeviceNotificationPresentation: Equatable {
    let title: String
    let body: String

    static func reconnected(
        deviceName: String,
        affectedAppCount: Int,
        language: AppLanguage,
        baseLocale: Locale = .autoupdatingCurrent
    ) -> Self {
        let localization = LocalizationContext(language: language, baseLocale: baseLocale)
        let title = localization.localized(
            LocalizedStringResource(
                "notification.audioDeviceReconnected.title",
                defaultValue: "Audio Device Reconnected"
            )
        )
        let afterDevice = localization.localized(
            LocalizedStringResource(
                "notification.audioDeviceReconnected.afterDevice",
                defaultValue: " is back. "
            )
        )
        let switchedBack = localization.localized(
            affectedAppCount == 1
                ? LocalizedStringResource(
                    "notification.oneAppSwitchedBack",
                    defaultValue: " app switched back."
                )
                : LocalizedStringResource(
                    "notification.manyAppsSwitchedBack",
                    defaultValue: " apps switched back."
                )
        )

        return Self(
            title: title,
            body: "“\(deviceName)”\(afterDevice)\(affectedAppCount)\(switchedBack)"
        )
    }

    static func disconnected(
        deviceName: String,
        fallbackName: String,
        affectedAppCount: Int,
        language: AppLanguage,
        baseLocale: Locale = .autoupdatingCurrent
    ) -> Self {
        let localization = LocalizationContext(language: language, baseLocale: baseLocale)
        let title = localization.localized(
            LocalizedStringResource(
                "notification.audioDeviceDisconnected.title",
                defaultValue: "Audio Device Disconnected"
            )
        )
        let afterDevice = localization.localized(
            LocalizedStringResource(
                "notification.audioDeviceDisconnected.afterDevice",
                defaultValue: " disconnected. "
            )
        )
        let switchedTo = switchedToText(
            affectedAppCount: affectedAppCount,
            localization: localization
        )
        let sentenceEnd = localization.localized(
            LocalizedStringResource(
                "notification.sentenceEnd",
                defaultValue: "."
            )
        )

        return Self(
            title: title,
            body: "“\(deviceName)”\(afterDevice)\(affectedAppCount)\(switchedTo)\(fallbackName)\(sentenceEnd)"
        )
    }

    static func defaultChanged(
        newDeviceName: String,
        affectedAppCount: Int,
        language: AppLanguage,
        baseLocale: Locale = .autoupdatingCurrent
    ) -> Self {
        let localization = LocalizationContext(language: language, baseLocale: baseLocale)
        let title = localization.localized(
            LocalizedStringResource(
                "notification.defaultAudioDeviceChanged.title",
                defaultValue: "Default Audio Device Changed"
            )
        )
        let switchedTo = switchedToText(
            affectedAppCount: affectedAppCount,
            localization: localization
        )
        let sentenceEnd = localization.localized(
            LocalizedStringResource(
                "notification.sentenceEnd",
                defaultValue: "."
            )
        )

        return Self(
            title: title,
            body: "\(affectedAppCount)\(switchedTo)“\(newDeviceName)”\(sentenceEnd)"
        )
    }

    private static func switchedToText(
        affectedAppCount: Int,
        localization: LocalizationContext
    ) -> String {
        localization.localized(
            affectedAppCount == 1
                ? LocalizedStringResource(
                    "notification.oneAppSwitchedTo",
                    defaultValue: " app switched to "
                )
                : LocalizedStringResource(
                    "notification.manyAppsSwitchedTo",
                    defaultValue: " apps switched to "
                )
        )
    }
}
