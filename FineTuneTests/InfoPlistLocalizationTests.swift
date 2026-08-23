import Foundation
import Testing

@Suite("Built Info.plist localization")
struct InfoPlistLocalizationTests {
    @Test("Simplified Chinese privacy purpose strings are compiled into the app bundle")
    func simplifiedChinesePrivacyPurposeStrings() throws {
        let appBundle = try #require(
            Bundle.allBundles.first { $0.bundleIdentifier == "com.finetuneapp.FineTune" }
        )
        let stringsURL = try #require(
            appBundle.url(
                forResource: "InfoPlist",
                withExtension: "strings",
                subdirectory: nil,
                localization: "zh-Hans"
            )
        )
        let data = try Data(contentsOf: stringsURL)
        let object = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )
        let strings = try #require(object as? [String: String])

        #expect(
            strings["NSAudioCaptureUsageDescription"]
                == "FineTune 需要访问系统音频，以便单独控制各个应用的音量。"
        )
        #expect(
            strings["NSBluetoothAlwaysUsageDescription"]
                == "FineTune 使用蓝牙，以便通过菜单栏连接已配对的音频设备。"
        )
        #expect(
            strings["NSMicrophoneUsageDescription"]
                == "FineTune 需要麦克风权限，以便在使用支持输入的音频设备时捕获应用音频。"
        )
    }
}
