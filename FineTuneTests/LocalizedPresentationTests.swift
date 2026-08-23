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

    @Test("Phase 4 popup and device resources resolve in both supported languages")
    func phase4Resources() {
        #expect(english.localized("Single") == "Single")
        #expect(chinese.localized("Single") == "单设备")
        #expect(english.localized("Multi") == "Multi")
        #expect(chinese.localized("Multi") == "多设备")
        #expect(english.localized("devices") == "devices")
        #expect(chinese.localized("devices") == "个设备")
        #expect(chinese.localized("System Audio") == "系统音频")
        #expect(chinese.localized("Reorder devices") == "调整设备顺序")
        #expect(chinese.localized("No Output") == "无输出设备")
        #expect(chinese.localized("No Input") == "无输入设备")
        #expect(chinese.localized("Output Devices") == "输出设备")
        #expect(chinese.localized("Input Devices") == "输入设备")
        #expect(english.localized("ignored") == "ignored")
        #expect(chinese.localized("ignored") == "个已忽略应用")
        #expect(chinese.localized("ignored · edit to manage") == "个已忽略应用 · 编辑以管理")
        #expect(chinese.localized("Quit FineTune") == "退出 FineTune")
    }

    @Test("Phase 5 EQ presentation localizes without changing preset identity")
    func phase5EQResources() {
        #expect(EQPreset.flat.rawValue == "flat")
        #expect(EQPreset.bassBoost.rawValue == "bassBoost")
        #expect(EQPreset.hipHop.rawValue == "hipHop")
        #expect(EQPreset.rnb.rawValue == "rnb")
        #expect(EQPreset.movie.rawValue == "movie")
        #expect(EQPreset.flat.name == "Flat")
        #expect(EQPreset.Category.music.rawValue == "Music")

        #expect(english.localized(EQPreset.flat.displayName) == "Flat")
        #expect(chinese.localized(EQPreset.flat.displayName) == "平直")
        #expect(english.localized(EQPreset.bassBoost.displayName) == "Bass Boost")
        #expect(chinese.localized(EQPreset.bassBoost.displayName) == "低频增强")
        #expect(english.localized(EQPreset.Category.music.displayName) == "Music")
        #expect(chinese.localized(EQPreset.Category.music.displayName) == "音乐")
        #expect(english.localized("My Presets") == "My Presets")
        #expect(chinese.localized("My Presets") == "我的预设")

        let userPreset = UserEQPreset(name: "Studio Mix", settings: EQSettings())
        let pickerItem = EQPickerItem(user: userPreset)
        #expect(pickerItem.name == "Studio Mix")
        #expect(pickerItem.userPresetID == userPreset.id)
    }

    @Test("Phase 5 AutoEQ presentation localizes while external profile data stays verbatim")
    func phase5AutoEQResources() {
        #expect(english.localized("Close AutoEQ") == "Close AutoEQ")
        #expect(chinese.localized("Close AutoEQ") == "关闭 AutoEQ")
        #expect(chinese.localized("AutoEQ correction") == "AutoEQ 校正")
        #expect(chinese.localized("No correction active") == "未启用校正")
        #expect(chinese.localized("Imported") == "已导入")
        #expect(chinese.localized("Correction") == "校正")
        #expect(chinese.localized("Preamp") == "前置增益")
        #expect(chinese.localized("Search headphones") == "搜索耳机")
        #expect(chinese.localized("Search headphones...") == "搜索耳机...")
        #expect(chinese.localized("FAVORITES") == "收藏")
        #expect(chinese.localized("results") == "个结果")
        #expect(chinese.localized("Import custom profile") == "导入自定义配置文件")

        let profile = AutoEQProfile(
            id: "sennheiser-hd-600",
            name: "Sennheiser HD 600",
            source: .fetched,
            preampDB: -6,
            filters: [],
            measuredBy: "oratory1990"
        )
        #expect(profile.id == "sennheiser-hd-600")
        #expect(profile.name == "Sennheiser HD 600")
        #expect(profile.measuredBy == "oratory1990")
        #expect(profile.source.rawValue == "fetched")
    }

    @Test("Phase 5 device presentation uses humanized Chinese while device facts stay stable")
    func phase5DeviceResources() {
        #expect(chinese.localized("Device inspector") == "设备详情")
        #expect(chinese.localized("Restore Default") == "恢复默认图标")
        #expect(chinese.localized("Transport") == "连接方式")
        #expect(chinese.localized("Sample rate") == "采样率")
        #expect(chinese.localized("Device ID") == "设备 ID")
        #expect(chinese.localized("Built-in") == "内置")
        #expect(chinese.localized("Virtual") == "虚拟")
        #expect(chinese.localized("In exclusive use by") == "独占使用：")
        #expect(chinese.localized("Use FineTune's software volume") == "使用 FineTune 软件音量控制")
        #expect(chinese.localized("Couldn't change sample rate. The device refused.") == "无法更改采样率，设备拒绝了此次更改。")
        #expect(chinese.localized(TransportType.builtIn.displayName) == "内置")

        let info = DeviceInspectorInfo(
            transportType: .usb,
            sampleRate: 48_000,
            availableSampleRates: [48_000],
            sampleRateSettable: false,
            formatLabel: "24-bit PCM",
            hogModeOwner: 4321,
            uid: "USB-Audio-123"
        )
        #expect(info.transportType == .usb)
        #expect(info.uid == "USB-Audio-123")
        #expect(info.formatLabel == "24-bit PCM")

        let owner = DeviceInspectorInfo.hogModeOwnerDetails(4321, processName: "Audirvana")
        #expect(owner?.pid == 4321)
        #expect(owner?.processName == "Audirvana")
    }

    @Test("Phase 7 completeness resources resolve to Simplified Chinese")
    func phase7CompletenessResources() {
        let expected: [(String, String)] = [
            ("Audio capture access required", "需要音频捕获权限"),
            ("Enable in System Settings → Privacy & Security → Screen & System Audio Recording", "请在“系统设置”→“隐私与安全性”→“屏幕与系统音频录制”中启用"),
            ("Open System Settings", "打开系统设置"),
            ("Grant Access", "授予权限"),
            ("Edit volume percentage", "编辑音量百分比"),
            ("Mute", "静音"),
            ("Unmute", "取消静音"),
            ("Mute microphone", "将麦克风静音"),
            ("Unmute microphone", "取消麦克风静音"),
            ("Default device", "默认设备"),
            ("Set as default", "设为默认设备"),
            ("Pin app", "固定应用"),
            ("Unpin app", "取消固定应用"),
            ("Ignore app", "忽略应用"),
            ("Stop ignoring", "取消忽略"),
            ("Close Equalizer", "关闭均衡器"),
            ("Connect", "连接"),
            ("Couldn't connect", "无法连接"),
            ("Connection timed out", "连接超时"),
            (" (off)", "（已关闭）"),
            ("Volume boost:", "音量增强："),
            ("Volume boost", "音量增强"),
            ("Open", "打开")
        ]

        for (source, translated) in expected {
            #expect(chinese.localized(source) == translated)
        }
    }
}
