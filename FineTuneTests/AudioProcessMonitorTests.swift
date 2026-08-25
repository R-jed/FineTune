import AppKit
import Testing
@testable import FineTune

@Suite("AudioProcessMonitor app discovery")
struct AudioProcessMonitorTests {
    @Test("Includes user GUI apps and filters background services")
    func userApplicationFilter() {
        let appURL = URL(fileURLWithPath: "/Applications/WeChat.app")
        let serviceURL = URL(fileURLWithPath: "/Applications/WeChat.app/Contents/XPCServices/Helper.xpc")
        let menuBarURL = URL(fileURLWithPath: "/Applications/MenuBarPlayer.app")
        let nestedHelperURL = URL(fileURLWithPath: "/Applications/Browser.app/Contents/Frameworks/Browser Helper.app")
        let systemServiceURL = URL(fileURLWithPath: "/System/Library/CoreServices/ControlCenter.app")

        #expect(AudioProcessMonitor.shouldIncludeUserApplication(
            activationPolicy: .regular,
            isTerminated: false,
            bundleURL: appURL
        ))
        #expect(!AudioProcessMonitor.shouldIncludeUserApplication(
            activationPolicy: .accessory,
            isTerminated: false,
            bundleURL: appURL
        ))
        #expect(AudioProcessMonitor.shouldIncludeUserApplication(
            activationPolicy: .accessory,
            isTerminated: false,
            bundleURL: menuBarURL,
            isAudioActive: true
        ))
        #expect(!AudioProcessMonitor.shouldIncludeUserApplication(
            activationPolicy: .accessory,
            isTerminated: false,
            bundleURL: nestedHelperURL,
            isAudioActive: true
        ))
        #expect(!AudioProcessMonitor.shouldIncludeUserApplication(
            activationPolicy: .accessory,
            isTerminated: false,
            bundleURL: systemServiceURL,
            isAudioActive: true
        ))
        #expect(!AudioProcessMonitor.shouldIncludeUserApplication(
            activationPolicy: .regular,
            isTerminated: false,
            bundleURL: serviceURL
        ))
        #expect(!AudioProcessMonitor.shouldIncludeUserApplication(
            activationPolicy: .regular,
            isTerminated: true,
            bundleURL: appURL
        ))
    }
}
