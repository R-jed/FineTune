import AppKit
import AudioToolbox
import Testing
@testable import FineTune

@Suite("Tap target policy")
@MainActor
struct TapTargetPolicyTests {
    private func app(
        processObjectIDs: [AudioObjectID] = [],
        bundleID: String? = "com.test.transient",
        isHelperBacked: Bool = false
    ) -> AudioApp {
        AudioApp(
            id: 60001,
            processObjectIDs: processObjectIDs,
            name: "Transient App",
            icon: NSImage(),
            bundleID: bundleID,
            isHelperBacked: isHelperBacked,
            isAudioActive: !processObjectIDs.isEmpty
        )
    }

    @Test("Quiet direct bundle prearm is available only where Core Audio supports it")
    func quietDirectBundleBuildsPrearmDescription() throws {
        let source = app()

        if #available(macOS 26.0, *) {
            let description = try #require(TapTargetPolicy.bundlePrearmDescription(for: source))
            #expect(TapTargetPolicy.canBundlePrearm(source))
            #expect(description.processes.isEmpty)
            #expect(description.bundleIDs == ["com.test.transient"])
            #expect(description.isExclusive == false)
            #expect(description.isMixdown)
            #expect(description.isMono == false)
            #expect(description.isPrivate)
            #expect(description.muteBehavior == .mutedWhenTapped)
            #expect(description.isProcessRestoreEnabled)
        } else {
            #expect(!TapTargetPolicy.canBundlePrearm(source))
            #expect(TapTargetPolicy.bundlePrearmDescription(for: source) == nil)
        }
    }

    @Test("Active process-object and known helper apps stay on process targeting")
    func activeAndHelperAppsDoNotBundlePrearm() {
        #expect(!TapTargetPolicy.canBundlePrearm(app(processObjectIDs: [AudioObjectID(9001)])))
        #expect(!TapTargetPolicy.canBundlePrearm(app(isHelperBacked: true)))
        #expect(!TapTargetPolicy.canBundlePrearm(app(bundleID: nil)))
    }

    @Test("Concrete tap survives transient process disappearance but rebuilds for a replacement object")
    func concreteTapLifetimePolicy() {
        let active = app(processObjectIDs: [AudioObjectID(9001)])
        let dormant = app()
        let replacement = app(processObjectIDs: [AudioObjectID(9002)])
        let helper = app(processObjectIDs: [AudioObjectID(9002)], isHelperBacked: true)
        let differentBundle = app(processObjectIDs: [AudioObjectID(9002)], bundleID: "com.test.other")

        #expect(TapTargetPolicy.shouldKeepBundlePrearm(existingApp: active, updatedApp: dormant))
        #expect(!TapTargetPolicy.shouldKeepBundlePrearm(existingApp: active, updatedApp: replacement))
        #expect(!TapTargetPolicy.shouldKeepBundlePrearm(existingApp: active, updatedApp: helper))
        #expect(!TapTargetPolicy.shouldKeepBundlePrearm(existingApp: active, updatedApp: differentBundle))
    }

    @Test("Bundle prearm survives direct process-object arrival only where supported")
    func bundlePrearmLifetimePolicy() {
        let quiet = app()
        let directReady = app(processObjectIDs: [AudioObjectID(9001)])
        let helperReady = app(processObjectIDs: [AudioObjectID(9002)], isHelperBacked: true)
        let differentBundle = app(
            processObjectIDs: [AudioObjectID(9003)],
            bundleID: "com.test.other"
        )

        if #available(macOS 26.0, *) {
            #expect(TapTargetPolicy.shouldKeepBundlePrearm(existingApp: quiet, updatedApp: directReady))
        } else {
            #expect(!TapTargetPolicy.shouldKeepBundlePrearm(existingApp: quiet, updatedApp: directReady))
        }
        #expect(!TapTargetPolicy.shouldKeepBundlePrearm(existingApp: quiet, updatedApp: helperReady))
        #expect(!TapTargetPolicy.shouldKeepBundlePrearm(existingApp: quiet, updatedApp: differentBundle))
    }
}
