import Foundation
import Testing
@testable import FineTune

@Suite("Device notification presentation")
struct DeviceNotificationPresentationTests {
    private let locale = Locale(identifier: "en_AU")

    @Test("English notification copy uses real singular and plural forms")
    func englishCopy() {
        let single = DeviceNotificationPresentation.reconnected(
            deviceName: "AirPods Pro",
            affectedAppCount: 1,
            language: .english,
            baseLocale: locale
        )
        #expect(single.title == "Audio Device Reconnected")
        #expect(single.body == "“AirPods Pro” is back. 1 app switched back.")

        let multiple = DeviceNotificationPresentation.disconnected(
            deviceName: "USB DAC",
            fallbackName: "MacBook Pro Speakers",
            affectedAppCount: 2,
            language: .english,
            baseLocale: locale
        )
        #expect(multiple.title == "Audio Device Disconnected")
        #expect(multiple.body == "“USB DAC” disconnected. 2 apps switched to “MacBook Pro Speakers”.")
    }

    @Test("English notification copy owns fallback device labels")
    func englishFallbackCopy() {
        let disconnected = DeviceNotificationPresentation.disconnected(
            deviceName: "USB DAC",
            fallbackName: nil,
            affectedAppCount: 1,
            language: .english,
            baseLocale: locale
        )
        #expect(disconnected.body == "“USB DAC” disconnected. 1 app switched to “none”.")

        let defaultChanged = DeviceNotificationPresentation.defaultChanged(
            newDeviceName: nil,
            affectedAppCount: 2,
            language: .english,
            baseLocale: locale
        )
        #expect(defaultChanged.body == "2 apps switched to “Default Output”.")
    }

    @Test("Simplified Chinese notification copy uses natural word order")
    func chineseCopy() {
        let reconnect = DeviceNotificationPresentation.reconnected(
            deviceName: "AirPods Pro",
            affectedAppCount: 2,
            language: .simplifiedChinese,
            baseLocale: locale
        )
        #expect(reconnect.title == "音频设备已重新连接")
        #expect(reconnect.body == "“AirPods Pro”已重新连接。2 个应用已切换回来。")

        let disconnect = DeviceNotificationPresentation.disconnected(
            deviceName: "USB DAC",
            fallbackName: "MacBook Pro Speakers",
            affectedAppCount: 2,
            language: .simplifiedChinese,
            baseLocale: locale
        )
        #expect(disconnect.title == "音频设备已断开连接")
        #expect(disconnect.body == "“USB DAC”已断开连接。2 个应用已切换到“MacBook Pro Speakers”。")

        let defaultChanged = DeviceNotificationPresentation.defaultChanged(
            newDeviceName: "AirPods Pro",
            affectedAppCount: 1,
            language: .simplifiedChinese,
            baseLocale: locale
        )
        #expect(defaultChanged.title == "默认音频设备已更改")
        #expect(defaultChanged.body == "1 个应用已切换到“AirPods Pro”。")
    }

    @Test("Simplified Chinese notification copy localizes fallback device labels")
    func chineseFallbackCopy() {
        let disconnected = DeviceNotificationPresentation.disconnected(
            deviceName: "USB DAC",
            fallbackName: nil,
            affectedAppCount: 1,
            language: .simplifiedChinese,
            baseLocale: locale
        )
        #expect(disconnected.body == "“USB DAC”已断开连接。1 个应用已切换到“无可用设备”。")

        let defaultChanged = DeviceNotificationPresentation.defaultChanged(
            newDeviceName: nil,
            affectedAppCount: 2,
            language: .simplifiedChinese,
            baseLocale: locale
        )
        #expect(defaultChanged.body == "2 个应用已切换到“默认输出设备”。")
    }

    @Test("Dynamic device names remain verbatim")
    func deviceNamesStayVerbatim() {
        let presentation = DeviceNotificationPresentation.disconnected(
            deviceName: "USB DAC α-2",
            fallbackName: "Studio Display 7.1",
            affectedAppCount: 1,
            language: .simplifiedChinese,
            baseLocale: locale
        )
        #expect(presentation.body.contains("USB DAC α-2"))
        #expect(presentation.body.contains("Studio Display 7.1"))
    }
}
