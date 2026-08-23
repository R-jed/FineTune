// FineTuneTests/LocalizedPresentationTests.swift
import Foundation
import Testing
@testable import FineTune

@Suite("Localized presentation resources")
struct LocalizedPresentationTests {
    private let english = LocalizationContext(
        language: .english,
        baseLocale: Locale(identifier: "en_AU")
    )
    private let chinese = LocalizationContext(
        language: .simplifiedChinese,
        baseLocale: Locale(identifier: "en_AU")
    )

    @Test("Existing persistence identifiers remain unchanged")
    func stablePersistenceIdentifiers() {
        #expect(AppLanguage.system.rawValue == "system")
        #expect(AppLanguage.english.rawValue == "en")
        #expect(AppLanguage.simplifiedChinese.rawValue == "zh-Hans")

        #expect(MenuBarIconStyle.default.rawValue == "Default")
        #expect(MenuBarIconStyle.speaker.rawValue == "Speaker")
        #expect(MenuBarIconStyle.device.rawValue == "Device")
        #expect(MenuBarIconStyle.waveform.rawValue == "Waveform")
        #expect(MenuBarIconStyle.equalizer.rawValue == "Equalizer")

        #expect(AppearancePreference.system.rawValue == "system")
        #expect(AppearancePreference.light.rawValue == "light")
        #expect(AppearancePreference.dark.rawValue == "dark")

        #expect(MenuBarPopupSize.compact.rawValue == "compact")
        #expect(MenuBarPopupSize.comfortable.rawValue == "comfortable")
        #expect(MenuBarPopupSize.spacious.rawValue == "spacious")

        #expect(VolumeHotkeyStep.coarse.rawValue == "coarse")
        #expect(VolumeHotkeyStep.normal.rawValue == "normal")
        #expect(VolumeHotkeyStep.fine.rawValue == "fine")
        #expect(VolumeHotkeyStep.extraFine.rawValue == "extraFine")

        #expect(HUDStyle.tahoe.rawValue == "tahoe")
        #expect(HUDStyle.classic.rawValue == "classic")

        #expect(ShortcutAction.togglePopup.rawValue == "togglePopup")
        #expect(ShortcutAction.targetAppVolumeUp.rawValue == "frontmostAppVolumeUp")
        #expect(ShortcutAction.targetAppVolumeDown.rawValue == "frontmostAppVolumeDown")
        #expect(ShortcutAction.targetAppMuteToggle.rawValue == "frontmostAppMuteToggle")

        #expect(VolumeControlTier.hardware.rawValue == "hardware")
        #expect(VolumeControlTier.ddc.rawValue == "ddc")
        #expect(VolumeControlTier.software.rawValue == "software")
    }

    @Test("English display resources resolve to source copy")
    func englishDisplayResources() {
        #expect(english.localized(AppLanguage.system.displayName) == "Follow System")
        #expect(english.localized(AppearancePreference.light.displayName) == "Light")
        #expect(english.localized(MenuBarPopupSize.comfortable.displayName) == "Comfortable")
        #expect(english.localized(VolumeHotkeyStep.extraFine.displayName) == "Extra-Fine (1.56%)")
        #expect(english.localized(MenuBarIconStyle.equalizer.displayName) == "Equalizer")
        #expect(english.localized(HUDStyle.classic.displayName) == "Classic")
        #expect(english.localized(ShortcutAction.targetAppMuteToggle.displayName) == "App Mute")
        #expect(english.localized(VolumeControlTier.hardware.displayName) == "Hardware")
    }

    @Test("Simplified Chinese display resources resolve through runtime override")
    func simplifiedChineseDisplayResources() {
        #expect(chinese.localized(AppLanguage.system.displayName) == "跟随系统")
        #expect(chinese.localized(AppearancePreference.light.displayName) == "浅色")
        #expect(chinese.localized(MenuBarPopupSize.comfortable.displayName) == "舒适")
        #expect(chinese.localized(VolumeHotkeyStep.extraFine.displayName) == "超细调 (1.56%)")
        #expect(chinese.localized(MenuBarIconStyle.equalizer.displayName) == "均衡器")
        #expect(chinese.localized(HUDStyle.classic.displayName) == "经典")
        #expect(chinese.localized(ShortcutAction.targetAppMuteToggle.displayName) == "应用静音")
        #expect(chinese.localized(VolumeControlTier.hardware.displayName) == "硬件")
    }

    @Test("Settings resources resolve in both supported languages")
    func settingsResources() {
        let resetConfirmationTitle = LocalizedStringResource(
            "settings.reset.confirmationTitle",
            defaultValue: "Reset all settings?"
        )

        #expect(english.localized("FineTune Settings") == "FineTune Settings")
        #expect(chinese.localized("FineTune Settings") == "FineTune 设置")
        #expect(english.localized("Language") == "Language")
        #expect(chinese.localized("Language") == "语言")
        #expect(english.localized("Software Updates") == "Software Updates")
        #expect(chinese.localized("Software Updates") == "软件更新")
        #expect(english.localized("Never checked") == "Never checked")
        #expect(chinese.localized("Never checked") == "从未检查")
        #expect(english.localized("Star on GitHub") == "Star on GitHub")
        #expect(chinese.localized("Star on GitHub") == "在 GitHub 加星")
        #expect(english.localized(resetConfirmationTitle) == "Reset all settings?")
        #expect(chinese.localized(resetConfirmationTitle) == "重置所有设置？")
    }
}
