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

    @Test("Quiet direct bundle builds a restoring muted mixdown tap")
    func quietDirectBundleBuildsPrearmDescription() throws {
        let source = app()
        let description = try #require(TapTargetPolicy.bundlePrearmDescription(for: source))

        #expect(description.processes.isEmpty)
        #expect(description.bundleIDs == ["com.test.transient"])
        #expect(description.isExclusive == false)
        #expect(description.isMixdown)
        #expect(description.isMono == false)
        #expect(description.isPrivate)
        #expect(description.muteBehavior == .mutedWhenTapped)
        #expect(description.isProcessRestoreEnabled)
    }

    @Test("Active process-object and known helper apps stay on process targeting")
    func activeAndHelperAppsDoNotBundlePrearm() {
        #expect(!TapTargetPolicy.canBundlePrearm(app(processObjectIDs: [AudioObjectID(9001)])))
        #expect(!TapTargetPolicy.canBundlePrearm(app(isHelperBacked: true)))
        #expect(!TapTargetPolicy.canBundlePrearm(app(bundleID: nil)))
    }

    @Test("Direct process-object churn keeps a bundle prearm but helper ownership retires it")
    func bundlePrearmLifetimePolicy() {
        let quiet = app()
        let directReady = app(processObjectIDs: [AudioObjectID(9001)])
        let helperReady = app(processObjectIDs: [AudioObjectID(9002)], isHelperBacked: true)
        let differentBundle = AudioApp(
            id: quiet.id,
            processObjectIDs: [AudioObjectID(9003)],
            name: quiet.name,
            icon: quiet.icon,
            bundleID: "com.test.other",
            isAudioActive: true
        )

        #expect(TapTargetPolicy.shouldKeepBundlePrearm(existingApp: quiet, updatedApp: directReady))
        #expect(!TapTargetPolicy.shouldKeepBundlePrearm(existingApp: quiet, updatedApp: helperReady))
        #expect(!TapTargetPolicy.shouldKeepBundlePrearm(existingApp: quiet, updatedApp: differentBundle))
    }
}
