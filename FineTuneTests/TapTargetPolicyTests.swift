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
        producerBundleIDs: [String] = [],
        isHelperBacked: Bool = false
    ) -> AudioApp {
        AudioApp(
            id: 60001,
            processObjectIDs: processObjectIDs,
            name: "Transient App",
            icon: NSImage(),
            bundleID: bundleID,
            producerBundleIDs: producerBundleIDs,
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

    @Test("macOS 26 bundle targeting covers identified active and helper producers")
    func activeAndHelperBundleTargeting() throws {
        let active = app(
            processObjectIDs: [AudioObjectID(9001)],
            producerBundleIDs: ["com.test.transient"]
        )
        let helper = app(
            processObjectIDs: [AudioObjectID(9002)],
            producerBundleIDs: ["com.test.transient.helper"],
            isHelperBacked: true
        )
        let unidentifiedActive = app(processObjectIDs: [AudioObjectID(9003)])
        let unidentifiedHelper = app(
            processObjectIDs: [AudioObjectID(9004)],
            isHelperBacked: true
        )

        if #available(macOS 26.0, *) {
            #expect(TapTargetPolicy.canBundlePrearm(active))
            #expect(TapTargetPolicy.canBundlePrearm(helper))
            #expect(!TapTargetPolicy.canBundlePrearm(unidentifiedActive))
            #expect(!TapTargetPolicy.canBundlePrearm(unidentifiedHelper))
            let helperDescription = try #require(TapTargetPolicy.bundlePrearmDescription(for: helper))
            #expect(helperDescription.bundleIDs == ["com.test.transient", "com.test.transient.helper"])
        } else {
            #expect(!TapTargetPolicy.canBundlePrearm(active))
            #expect(!TapTargetPolicy.canBundlePrearm(helper))
            #expect(!TapTargetPolicy.canBundlePrearm(unidentifiedActive))
            #expect(!TapTargetPolicy.canBundlePrearm(unidentifiedHelper))
        }

        #expect(!TapTargetPolicy.canBundlePrearm(app(bundleID: nil)))
    }

    @Test("Existing target ignores lifecycle flicker but rejects uncovered producer identity")
    func targetLifetimePolicy() {
        let active = app(
            processObjectIDs: [AudioObjectID(9001), AudioObjectID(9002)],
            producerBundleIDs: ["com.test.transient"]
        )
        let dormant = app()
        let subset = app(
            processObjectIDs: [AudioObjectID(9001)],
            producerBundleIDs: ["com.test.transient"]
        )
        let replacement = app(
            processObjectIDs: [AudioObjectID(9003)],
            producerBundleIDs: ["com.test.transient"]
        )
        let superset = app(
            processObjectIDs: [AudioObjectID(9001), AudioObjectID(9002), AudioObjectID(9003)],
            producerBundleIDs: ["com.test.transient"]
        )
        let knownHelper = app(
            processObjectIDs: [AudioObjectID(9003)],
            producerBundleIDs: ["com.test.transient.helper"],
            isHelperBacked: true
        )
        let differentBundle = app(
            processObjectIDs: [AudioObjectID(9001)],
            bundleID: "com.test.other",
            producerBundleIDs: ["com.test.other"]
        )

        #expect(TapTargetPolicy.shouldKeepBundlePrearm(existingApp: active, updatedApp: dormant))
        #expect(TapTargetPolicy.shouldKeepBundlePrearm(existingApp: active, updatedApp: subset))
        #expect(!TapTargetPolicy.shouldKeepBundlePrearm(existingApp: active, updatedApp: differentBundle))

        if #available(macOS 26.0, *) {
            #expect(TapTargetPolicy.shouldKeepBundlePrearm(existingApp: active, updatedApp: replacement))
            #expect(TapTargetPolicy.shouldKeepBundlePrearm(existingApp: active, updatedApp: superset))
            #expect(!TapTargetPolicy.shouldKeepBundlePrearm(existingApp: active, updatedApp: knownHelper))
        } else {
            #expect(!TapTargetPolicy.shouldKeepBundlePrearm(existingApp: active, updatedApp: replacement))
            #expect(!TapTargetPolicy.shouldKeepBundlePrearm(existingApp: active, updatedApp: superset))
            #expect(!TapTargetPolicy.shouldKeepBundlePrearm(existingApp: active, updatedApp: knownHelper))
        }
    }

    @Test("Learned helper producer identity remains covered after process-object disappearance")
    func learnedHelperIdentitySurvivesFlicker() {
        let helper = app(
            processObjectIDs: [AudioObjectID(9002)],
            producerBundleIDs: ["com.test.transient.helper"],
            isHelperBacked: true
        )
        let helperDormant = app(
            producerBundleIDs: ["com.test.transient.helper"],
            isHelperBacked: true
        )

        #expect(TapTargetPolicy.shouldKeepBundlePrearm(existingApp: helper, updatedApp: helperDormant))
    }

    @Test("A parent-only prearm must expand when a new helper producer is learned")
    func helperProducerExpansionRequiresNewTarget() {
        let quiet = app()
        let directReady = app(
            processObjectIDs: [AudioObjectID(9001)],
            producerBundleIDs: ["com.test.transient"]
        )
        let helperReady = app(
            processObjectIDs: [AudioObjectID(9002)],
            producerBundleIDs: ["com.test.transient.helper"],
            isHelperBacked: true
        )

        if #available(macOS 26.0, *) {
            #expect(TapTargetPolicy.shouldKeepBundlePrearm(existingApp: quiet, updatedApp: directReady))
            #expect(!TapTargetPolicy.shouldKeepBundlePrearm(existingApp: quiet, updatedApp: helperReady))
        } else {
            #expect(!TapTargetPolicy.shouldKeepBundlePrearm(existingApp: quiet, updatedApp: directReady))
            #expect(!TapTargetPolicy.shouldKeepBundlePrearm(existingApp: quiet, updatedApp: helperReady))
        }
    }
}
