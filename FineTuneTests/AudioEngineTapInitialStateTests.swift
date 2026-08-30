// FineTuneTests/AudioEngineTapInitialStateTests.swift
//
// Verifies AudioEngine derives TapInitialState from persisted settings and
// hands it to activate(initial:) before any post-activation mutation.

import Testing
import Foundation
import AppKit
import AudioToolbox
@testable import FineTune

// MARK: - Recording Mock

/// Records every method invocation against `ProcessTapControlling` in order.
/// Tests assert on `events` to verify the engine's apply-initial-state contract.
@MainActor
final class RecordingProcessTapController: ProcessTapControlling {
    enum Event: Equatable {
        case activate(TapInitialStateSnapshot)
        case updateEQSettings(EQSettings)
        case updateAutoEQProfile(profileID: String?)
        case setAutoEQPreampEnabled(Bool)
        case updateLoudnessCompensation(volume: Float, enabled: Bool)
        case updateLoudnessEqualization(LoudnessEqualizerSettings)
        case invalidate
    }

    /// Plain snapshot of `TapInitialState` so test asserts don't depend on
    /// the source-type's identity (defensive against future mutations).
    struct TapInitialStateSnapshot: Equatable {
        var eqSettings: EQSettings
        var autoEQProfileID: String?
        var autoEQPreampEnabled: Bool
        var loudnessVolume: Float
        var loudnessCompensationEnabled: Bool
        var loudnessEqualizerSettings: LoudnessEqualizerSettings

        @MainActor
        init(_ s: TapInitialState) {
            self.eqSettings = s.eqSettings
            self.autoEQProfileID = s.autoEQProfile?.id
            self.autoEQPreampEnabled = s.autoEQPreampEnabled
            self.loudnessVolume = s.loudnessVolume
            self.loudnessCompensationEnabled = s.loudnessCompensationEnabled
            self.loudnessEqualizerSettings = s.loudnessEqualizerSettings
        }
    }

    let app: AudioApp
    private(set) var events: [Event] = []

    // Mutable surface — recorded as plain property writes (not events).
    var volume: Float = 1.0
    var isMuted: Bool = false
    var currentDeviceVolume: Float = 1.0
    var isDeviceMuted: Bool = false
    var audioLevel: Float = 0.0
    private(set) var currentDeviceUIDs: [String]
    var currentDeviceUID: String? { currentDeviceUIDs.first }
    var tapSourceDeviceUID: String? = nil

    init(app: AudioApp, deviceUIDs: [String]) {
        self.app = app
        self.currentDeviceUIDs = deviceUIDs
    }

    func activate(initial: TapInitialState) throws {
        events.append(.activate(TapInitialStateSnapshot(initial)))
    }

    func invalidate() {
        events.append(.invalidate)
    }

    func updateEQSettings(_ settings: EQSettings) {
        events.append(.updateEQSettings(settings))
    }

    func updateAutoEQProfile(_ profile: AutoEQProfile?) {
        events.append(.updateAutoEQProfile(profileID: profile?.id))
    }

    func setAutoEQPreampEnabled(_ enabled: Bool) {
        events.append(.setAutoEQPreampEnabled(enabled))
    }

    func updateLoudnessCompensation(volume: Float, enabled: Bool) {
        events.append(.updateLoudnessCompensation(volume: volume, enabled: enabled))
    }

    func updateLoudnessEqualization(_ settings: LoudnessEqualizerSettings) {
        events.append(.updateLoudnessEqualization(settings))
    }

    func switchDevice(to newDeviceUID: String, preferredTapSourceDeviceUID: String?, sourceDeviceDead: Bool) async throws {
        currentDeviceUIDs = [newDeviceUID]
    }

    func updateDevices(to newDeviceUIDs: [String], preferredTapSourceDeviceUID: String?, sourceDeviceDead: Bool) async throws {
        currentDeviceUIDs = newDeviceUIDs
    }

    func hasRecentAudioCallback(within seconds: Double) -> Bool { false }
    func isHealthCheckEligible(minActiveSeconds: Double) -> Bool { false }

    func refreshTapSource(_ preferredDeviceUID: String?) async throws {}
}

// MARK: - Process monitor stub

@MainActor
final class StubProcessMonitor: AudioProcessMonitoring {
    var activeApps: [AudioApp] = []
    var onAppsChanged: (([AudioApp]) -> Void)?
    func start() {}
    func stop() {}

    func setActiveApps(_ apps: [AudioApp]) {
        activeApps = apps
        onAppsChanged?(apps)
    }
}

// MARK: - Fixture

@MainActor
private struct Fixture {
    let engine: AudioEngine
    let settings: SettingsManager
    let processMonitor: StubProcessMonitor
    let deviceMonitor: MockAudioDeviceMonitor
    let deviceVolume: MockDeviceVolumeProviding
    let app: AudioApp
    let device: AudioDevice
    let lastTap: () -> RecordingProcessTapController?
}

@MainActor
private func makeFixture(
    supportsAutoEQ: Bool = true,
    deviceVolume: Float = 0.75
) -> Fixture {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    let settings = SettingsManager(directory: tempDir)

    let deviceMonitor = MockAudioDeviceMonitor()
    let device = AudioDevice(
        id: AudioDeviceID(99),
        uid: "uid-test",
        name: "Test Output",
        icon: nil,
        supportsAutoEQ: supportsAutoEQ
    )
    deviceMonitor.addOutputDevice(device)

    let mockVolume = MockDeviceVolumeProviding(deviceMonitor: deviceMonitor)
    mockVolume.volumes[device.id] = deviceVolume
    mockVolume.defaultDeviceUID = device.uid

    let app = AudioApp(
        id: 12345,
        processObjectIDs: [AudioObjectID(999)],
        name: "TestApp",
        icon: NSImage(),
        bundleID: "com.test.tapinitial"
    )

    let processMonitor = StubProcessMonitor()
    processMonitor.activeApps = [app]

    // Capture every tap the factory hands out so tests can read the captured
    // event log. Mutable box lets the closure write into the test scope.
    let box = TapBox()

    // ensureTapExists guards on permission.status == .authorized. The TCC SPI
    // preflight returns -1 (unknown) under xctest, so we force it to authorized
    // via the internal(set) status property exposed by @testable import.
    let permission = AudioRecordingPermission()
    permission.status = .authorized

    let engine = AudioEngine(
        permission: permission,
        settingsManager: settings,
        autoEQProfileManager: AutoEQProfileManager(),
        deviceProvider: deviceMonitor,
        processMonitor: processMonitor,
        deviceVolumeMonitor: mockVolume,
        tapFactory: { app, uids, _ in
            let tap = RecordingProcessTapController(app: app, deviceUIDs: uids)
            box.last = tap
            return tap
        },
        startMonitorsAutomatically: false
    )

    return Fixture(
        engine: engine,
        settings: settings,
        processMonitor: processMonitor,
        deviceMonitor: deviceMonitor,
        deviceVolume: mockVolume,
        app: app,
        device: device,
        lastTap: { box.last }
    )
}

@MainActor
private final class TapBox {
    var last: RecordingProcessTapController?
}

// MARK: - Suite

@Suite("AudioEngine.tapInitialState — first-sound fix (PR-1)")
@MainActor
struct AudioEngineTapInitialStateTests {

    @Test("A process object disappearance preserves the tap until a replacement object appears")
    func processObjectReplacementRebuildsTap() {
        let fix = makeFixture()
        fix.engine.applyPersistedSettings()
        let originalTap = fix.lastTap()

        let quietApp = AudioApp(
            id: fix.app.id,
            processObjectIDs: [],
            name: fix.app.name,
            icon: fix.app.icon,
            bundleID: fix.app.bundleID,
            isAudioActive: false
        )
        fix.processMonitor.setActiveApps([quietApp])

        #expect(originalTap?.events.contains(.invalidate) == false)
        #expect(fix.lastTap() === originalTap)
        #expect(fix.engine.getAudioLevel(for: quietApp) == 0)

        let resumedApp = AudioApp(
            id: fix.app.id,
            processObjectIDs: [AudioObjectID(1000)],
            name: fix.app.name,
            icon: fix.app.icon,
            bundleID: fix.app.bundleID,
            isAudioActive: true
        )
        fix.processMonitor.setActiveApps([resumedApp])

        #expect(originalTap?.events.contains(.invalidate) == true)
        #expect(fix.lastTap() !== originalTap)
        #expect(fix.lastTap()?.app.processObjectIDs == resumedApp.processObjectIDs)
    }

    @Test("A quiet running app remains visible without pinning")
    func quietRunningAppRemainsVisible() {
        let fix = makeFixture()
        let quietApp = AudioApp(
            id: fix.app.id,
            processObjectIDs: [],
            name: fix.app.name,
            icon: fix.app.icon,
            bundleID: fix.app.bundleID,
            isAudioActive: false
        )
        fix.processMonitor.activeApps = [quietApp]

        #expect(fix.engine.displayableApps.map(\.id) == [quietApp.persistenceIdentifier])
    }

    @Test("Pinned app stays visible while inactive and relaunches into the same identity")
    func pinnedAppLifecyclePreservesRowIdentity() throws {
        let fix = makeFixture()
        let identifier = fix.app.persistenceIdentifier

        fix.engine.setPinned(identifier, pinned: true)
        #expect(fix.engine.isPinned(identifier: identifier))
        #expect(fix.engine.displayableApps.map(\.id) == [identifier])

        fix.processMonitor.setActiveApps([])
        let inactive = try #require(fix.engine.displayableApps.first)
        guard case .pinnedInactive(let info) = inactive else {
            Issue.record("Expected pinned inactive row after process exit")
            return
        }
        #expect(info.persistenceIdentifier == identifier)

        fix.processMonitor.setActiveApps([fix.app])
        let relaunched = try #require(fix.engine.displayableApps.first)
        guard case .active(let app) = relaunched else {
            Issue.record("Expected active row after relaunch")
            return
        }
        #expect(app.persistenceIdentifier == identifier)
    }

    @Test("Unpinning an inactive app removes its row but keeps its latent order slot")
    func unpinInactiveRemovesOnlyDisplayEligibility() {
        let fix = makeFixture()
        let identifier = fix.app.persistenceIdentifier
        fix.engine.setPinned(identifier, pinned: true)
        fix.processMonitor.setActiveApps([])
        #expect(fix.engine.displayableApps.map(\.id) == [identifier])

        fix.engine.setPinned(identifier, pinned: false)

        #expect(fix.engine.displayableApps.isEmpty)
        #expect(!fix.engine.isPinned(identifier: identifier))
        #expect(fix.settings.appOrder.contains(identifier))
    }

    @Test("Hidden pinned app remains hidden without losing pin membership")
    func hiddenPinnedAppStaysHidden() {
        let fix = makeFixture()
        let identifier = fix.app.persistenceIdentifier
        fix.engine.setPinned(identifier, pinned: true)

        fix.engine.ignoreApp(fix.app)

        #expect(fix.engine.displayableApps.isEmpty)
        #expect(fix.engine.isPinned(identifier: identifier))
        #expect(fix.engine.isIgnored(identifier: identifier))
    }

    @Test("Cross-section placement changes membership and preserves the chosen visible position")
    func crossSectionPlacementCommitsOrderAndMembershipTogether() {
        let fix = makeFixture()
        let second = AudioApp(
            id: 54321,
            processObjectIDs: [],
            name: "Second",
            icon: NSImage(),
            bundleID: "com.test.second"
        )
        fix.processMonitor.setActiveApps([fix.app, second])
        fix.engine.setPinned(fix.app.persistenceIdentifier, pinned: true)
        #expect(fix.engine.displayableApps.map(\.id) == [
            fix.app.persistenceIdentifier,
            second.persistenceIdentifier,
        ])

        let changed = fix.engine.placeApp(
            second.persistenceIdentifier,
            visibleOrder: [second.persistenceIdentifier, fix.app.persistenceIdentifier],
            pinned: true
        )

        #expect(changed)
        #expect(fix.engine.isPinned(identifier: second.persistenceIdentifier))
        #expect(fix.engine.displayableApps.map(\.id) == [
            second.persistenceIdentifier,
            fix.app.persistenceIdentifier,
        ])
    }

    @Test("Pin button defaults place pinned apps at the end and unpinned apps at the beginning")
    func pinToggleUsesSectionEdgeDefaults() {
        let fix = makeFixture()
        let second = AudioApp(
            id: 54321,
            processObjectIDs: [],
            name: "Second",
            icon: NSImage(),
            bundleID: "com.test.second"
        )
        let third = AudioApp(
            id: 54322,
            processObjectIDs: [],
            name: "Third",
            icon: NSImage(),
            bundleID: "com.test.third"
        )
        fix.settings.ensureAppsInOrder([
            fix.app.persistenceIdentifier,
            second.persistenceIdentifier,
            third.persistenceIdentifier,
        ])
        fix.processMonitor.setActiveApps([fix.app, second, third])

        fix.engine.setPinned(fix.app.persistenceIdentifier, pinned: true)
        fix.engine.setPinned(third.persistenceIdentifier, pinned: true)
        #expect(fix.engine.displayableApps.map(\.id) == [
            fix.app.persistenceIdentifier,
            third.persistenceIdentifier,
            second.persistenceIdentifier,
        ])

        fix.engine.setPinned(fix.app.persistenceIdentifier, pinned: false)
        #expect(fix.engine.displayableApps.map(\.id) == [
            third.persistenceIdentifier,
            fix.app.persistenceIdentifier,
            second.persistenceIdentifier,
        ])
    }

    @Test("Re-adding an already pinned app is idempotent and preserves its position")
    func repeatedAddApplicationPreservesPinnedPosition() {
        let fix = makeFixture()
        let second = AudioApp(
            id: 54321,
            processObjectIDs: [],
            name: "Second",
            icon: NSImage(),
            bundleID: "com.test.second"
        )
        fix.settings.ensureAppsInOrder([fix.app.persistenceIdentifier, second.persistenceIdentifier])
        fix.processMonitor.setActiveApps([fix.app, second])
        fix.settings.ensureAppsInOrder([second.persistenceIdentifier, fix.app.persistenceIdentifier])
        fix.engine.setPinned(fix.app.persistenceIdentifier, pinned: true)

        let before = fix.engine.displayableApps.map(\.id)
        let rawBefore = fix.settings.appOrder
        fix.engine.addSelectedApplication(
            PinnedAppInfo(
                persistenceIdentifier: fix.app.persistenceIdentifier,
                displayName: fix.app.name,
                bundleID: fix.app.bundleID
            )
        )

        #expect(fix.engine.displayableApps.map(\.id) == before)
        #expect(fix.settings.appOrder == rawBefore)
    }

    @Test("Representative PID migration retires the old tap before provisioning the new representative")
    func representativePIDMigrationRetiresOldTap() throws {
        let fix = makeFixture()
        fix.engine.applyPersistedSettings()
        let originalTap = try #require(fix.lastTap())

        let replacement = AudioApp(
            id: 54321,
            processObjectIDs: [AudioObjectID(1000)],
            name: fix.app.name,
            icon: fix.app.icon,
            bundleID: fix.app.bundleID,
            isAudioActive: true
        )
        fix.processMonitor.setActiveApps([replacement])

        #expect(originalTap.events.contains(.invalidate))
        let replacementTap = try #require(fix.lastTap())
        #expect(replacementTap !== originalTap)
        #expect(replacementTap.app.id == replacement.id)
    }

    @Test("PID reuse by another app retires the old tap and applies the new app state")
    func reusedPIDResetsIdentity() throws {
        let fix = makeFixture()
        fix.engine.setVolume(for: fix.app, to: 0.25)
        fix.engine.applyPersistedSettings()
        let originalTap = try #require(fix.lastTap())

        let replacement = AudioApp(
            id: fix.app.id,
            processObjectIDs: fix.app.processObjectIDs,
            name: "Replacement",
            icon: NSImage(),
            bundleID: "com.test.replacement",
            isAudioActive: true
        )
        fix.settings.setVolume(for: replacement.persistenceIdentifier, to: 0.8)
        fix.processMonitor.setActiveApps([replacement])

        #expect(originalTap.events.contains(.invalidate))
        let replacementTap = try #require(fix.lastTap())
        #expect(replacementTap !== originalTap)
        #expect(replacementTap.app.persistenceIdentifier == replacement.persistenceIdentifier)
        #expect(fix.engine.getVolume(for: replacement) == 0.8)
    }

    @Test("Unhiding a non-running app preserves settings but does not create a row")
    func unhideNonRunningAppDoesNotCreateRow() {
        let fix = makeFixture()
        let identifier = "com.test.manual"
        fix.processMonitor.activeApps = []
        fix.settings.setVolume(for: identifier, to: 0.42)
        fix.settings.ignoreApp(
            identifier,
            info: IgnoredAppInfo(
                persistenceIdentifier: identifier,
                displayName: "Manual App",
                bundleID: identifier
            )
        )

        fix.engine.unignoreApp(identifier)

        #expect(fix.engine.displayableApps.isEmpty)
        #expect(fix.settings.getVolume(for: identifier) == 0.42)
        #expect(!fix.settings.isIgnored(identifier))
    }

    @Test("Multiple processes for one bundle produce one visible row")
    func duplicateBundleProducesOneRow() {
        let fix = makeFixture()
        let quietProcess = AudioApp(
            id: fix.app.id,
            processObjectIDs: [AudioObjectID(999)],
            name: fix.app.name,
            icon: fix.app.icon,
            bundleID: fix.app.bundleID,
            isAudioActive: false
        )
        let secondProcess = AudioApp(
            id: 54321,
            processObjectIDs: [AudioObjectID(1000)],
            name: fix.app.name,
            icon: fix.app.icon,
            bundleID: fix.app.bundleID,
            isAudioActive: true
        )
        fix.processMonitor.activeApps = [quietProcess, secondProcess]

        #expect(fix.engine.displayableApps.map(\.id) == [fix.app.persistenceIdentifier])
        guard let merged = fix.engine.displayableApps.first?.app else {
            Issue.record("Expected one merged running app")
            return
        }
        #expect(merged.processObjectIDs == [AudioObjectID(999), AudioObjectID(1000)])
        #expect(merged.isAudioActive)
    }

    @Test("An app exit and relaunch restores its latent global order slot")
    func relaunchRestoresLatentOrder() {
        let fix = makeFixture()
        let second = AudioApp(
            id: 54321,
            processObjectIDs: [],
            name: "Bravo",
            icon: NSImage(),
            bundleID: "com.test.bravo"
        )
        let third = AudioApp(
            id: 54322,
            processObjectIDs: [],
            name: "Charlie",
            icon: NSImage(),
            bundleID: "com.test.charlie"
        )
        fix.settings.ensureAppsInOrder([
            fix.app.persistenceIdentifier,
            second.persistenceIdentifier,
            third.persistenceIdentifier,
        ])
        fix.processMonitor.setActiveApps([fix.app, second, third])
        fix.engine.moveApp(third.persistenceIdentifier, to: fix.app.persistenceIdentifier)
        #expect(fix.engine.displayableApps.map(\.id) == [
            third.persistenceIdentifier,
            fix.app.persistenceIdentifier,
            second.persistenceIdentifier,
        ])

        fix.processMonitor.setActiveApps([fix.app, third])
        fix.engine.moveApp(fix.app.persistenceIdentifier, to: third.persistenceIdentifier)
        #expect(fix.engine.displayableApps.map(\.id) == [
            fix.app.persistenceIdentifier,
            third.persistenceIdentifier,
        ])

        fix.processMonitor.setActiveApps([fix.app, second, third])
        #expect(fix.engine.displayableApps.map(\.id) == [
            fix.app.persistenceIdentifier,
            second.persistenceIdentifier,
            third.persistenceIdentifier,
        ])
    }

    @Test("Hidden app keeps its latent anchor while visible apps reorder and returns on unhide")
    func hiddenAppRestoresLatentOrderAfterVisibleReorder() {
        let fix = makeFixture()
        let hidden = AudioApp(
            id: 54321,
            processObjectIDs: [],
            name: "Bravo",
            icon: NSImage(),
            bundleID: "com.test.bravo"
        )
        let third = AudioApp(
            id: 54322,
            processObjectIDs: [],
            name: "Charlie",
            icon: NSImage(),
            bundleID: "com.test.charlie"
        )
        fix.settings.ensureAppsInOrder([
            fix.app.persistenceIdentifier,
            hidden.persistenceIdentifier,
            third.persistenceIdentifier,
        ])
        fix.processMonitor.setActiveApps([fix.app, hidden, third])
        fix.engine.setVolume(for: hidden, to: 0.42)

        fix.engine.ignoreApp(hidden)
        #expect(fix.engine.displayableApps.map(\.id) == [
            fix.app.persistenceIdentifier,
            third.persistenceIdentifier,
        ])

        fix.engine.moveApp(fix.app.persistenceIdentifier, to: third.persistenceIdentifier)
        #expect(fix.engine.displayableApps.map(\.id) == [
            third.persistenceIdentifier,
            fix.app.persistenceIdentifier,
        ])

        fix.engine.unignoreApp(hidden.persistenceIdentifier)

        #expect(fix.engine.displayableApps.map(\.id) == [
            third.persistenceIdentifier,
            fix.app.persistenceIdentifier,
            hidden.persistenceIdentifier,
        ])
        #expect(fix.settings.getVolume(for: hidden.persistenceIdentifier) == 0.42)
    }

    @Test("Applications preserve user-defined order within their section")
    func applicationsCanBeReordered() {
        let fix = makeFixture()
        let second = AudioApp(
            id: 54321,
            processObjectIDs: [],
            name: "Zulu App",
            icon: NSImage(),
            bundleID: "com.test.zulu"
        )
        fix.settings.ensureAppsInOrder([fix.app.persistenceIdentifier, second.persistenceIdentifier])
        fix.processMonitor.setActiveApps([fix.app, second])

        fix.engine.moveApp(second.persistenceIdentifier, to: fix.app.persistenceIdentifier)

        #expect(fix.engine.displayableApps.map(\.id) == [
            second.persistenceIdentifier,
            fix.app.persistenceIdentifier,
        ])
    }

    @Test("One-click mute updates live audio and persistence")
    func muteUpdatesTapAndPersistence() throws {
        let fix = makeFixture()
        fix.engine.setDevice(for: fix.app, deviceUID: fix.device.uid)
        let tap = try #require(fix.lastTap())

        fix.engine.setMute(for: fix.app, to: true)

        #expect(fix.engine.isMuted(for: fix.app))
        #expect(tap.isMuted)
        #expect(fix.settings.getMute(for: fix.app.persistenceIdentifier) == true)

        fix.engine.setMute(for: fix.app, to: false)

        #expect(!fix.engine.isMuted(for: fix.app))
        #expect(!tap.isMuted)
        #expect(fix.settings.getMute(for: fix.app.persistenceIdentifier) == false)
    }

    @Test("Hiding tears down live audio and restoring provisions it again")
    func hideAndRestoreUpdatesLiveAudio() throws {
        let fix = makeFixture()
        fix.engine.setDevice(for: fix.app, deviceUID: fix.device.uid)
        let firstTap = try #require(fix.lastTap())

        fix.engine.ignoreApp(fix.app)

        #expect(fix.engine.displayableApps.isEmpty)
        #expect(firstTap.events.contains(.invalidate))

        fix.engine.unignoreApp(fix.app.persistenceIdentifier)
        let restoredTap = try #require(fix.lastTap())

        #expect(fix.engine.displayableApps.map(\.id) == [fix.app.persistenceIdentifier])
        #expect(restoredTap !== firstTap)
    }

    // MARK: Single-knob derivation

    @Test("EQ settings persisted for this app land in TapInitialState.eqSettings")
    func eqSettingsAreCarried() throws {
        let fix = makeFixture()
        let custom = EQSettings(bandGains: [3, 0, -2, 0, 0, 0, 0, 0, 0, 4], isEnabled: true)
        fix.settings.setEQSettings(custom, for: fix.app.persistenceIdentifier)

        fix.engine.setDevice(for: fix.app, deviceUID: fix.device.uid)

        let snap = try #require(capturedInitial(fix))
        #expect(snap.eqSettings == custom)
    }

    @Test("autoEQPreampEnabled mirrors settingsManager.autoEQPreampEnabled",
          arguments: [true, false])
    func autoEQPreampEnabledMirrored(value: Bool) throws {
        let fix = makeFixture()
        fix.settings.autoEQPreampEnabled = value

        fix.engine.setDevice(for: fix.app, deviceUID: fix.device.uid)

        let snap = try #require(capturedInitial(fix))
        #expect(snap.autoEQPreampEnabled == value)
    }

    @Test("loudnessCompensationEnabled mirrors appSettings.loudnessCompensationEnabled",
          arguments: [true, false])
    func loudnessCompensationFlagMirrored(value: Bool) throws {
        let fix = makeFixture()
        var s = fix.settings.appSettings
        s.loudnessCompensationEnabled = value
        fix.settings.updateAppSettings(s)

        fix.engine.setDevice(for: fix.app, deviceUID: fix.device.uid)

        let snap = try #require(capturedInitial(fix))
        #expect(snap.loudnessCompensationEnabled == value)
    }

    @Test("loudnessEqualizerSettings.enabled mirrors appSettings.loudnessEqualizationEnabled",
          arguments: [true, false])
    func loudnessEqualizerFlagMirrored(value: Bool) throws {
        let fix = makeFixture()
        var s = fix.settings.appSettings
        s.loudnessEqualizationEnabled = value
        fix.settings.updateAppSettings(s)

        fix.engine.setDevice(for: fix.app, deviceUID: fix.device.uid)

        let snap = try #require(capturedInitial(fix))
        #expect(snap.loudnessEqualizerSettings.enabled == value)
    }

    @Test("loudnessVolume = currentDeviceVolume × per-app volume")
    func loudnessVolumeIsProduct() throws {
        let fix = makeFixture(deviceVolume: 0.5)
        fix.engine.volumeState.setVolume(for: fix.app.id, to: 0.4, identifier: fix.app.persistenceIdentifier)

        fix.engine.setDevice(for: fix.app, deviceUID: fix.device.uid)

        let snap = try #require(capturedInitial(fix))
        // applyTapOutputState() runs before tapInitialState() is built, so
        // currentDeviceVolume is 0.5 (from MockDeviceVolumeProviding.volumes).
        // loudnessVolume should be deviceVolume (0.5) × appVolume (0.4) = 0.2.
        #expect(abs(snap.loudnessVolume - 0.2) < 1e-6)
    }

    // MARK: AutoEQ profile resolution

    @Test("autoEQProfile is nil when the device does not support AutoEQ")
    func autoEQNilForUnsupportedDevice() throws {
        let fix = makeFixture(supportsAutoEQ: false)
        // Even if a selection exists, an unsupported device must skip AutoEQ.
        fix.settings.setAutoEQSelection(
            for: fix.device.uid,
            to: AutoEQSelection(profileID: "any-id", isEnabled: true)
        )

        fix.engine.setDevice(for: fix.app, deviceUID: fix.device.uid)

        let snap = try #require(capturedInitial(fix))
        #expect(snap.autoEQProfileID == nil)
    }

    @Test("autoEQProfile is nil when no selection is persisted for the device")
    func autoEQNilWithNoSelection() throws {
        let fix = makeFixture(supportsAutoEQ: true)
        // Don't set any selection.

        fix.engine.setDevice(for: fix.app, deviceUID: fix.device.uid)

        let snap = try #require(capturedInitial(fix))
        #expect(snap.autoEQProfileID == nil)
    }

    @Test("autoEQProfile is nil when the selection is disabled")
    func autoEQNilWhenSelectionDisabled() throws {
        let fix = makeFixture(supportsAutoEQ: true)
        fix.settings.setAutoEQSelection(
            for: fix.device.uid,
            to: AutoEQSelection(profileID: "any-id", isEnabled: false)
        )

        fix.engine.setDevice(for: fix.app, deviceUID: fix.device.uid)

        let snap = try #require(capturedInitial(fix))
        #expect(snap.autoEQProfileID == nil)
    }

    @Test("autoEQProfile is nil when selection is enabled but profile is not in the cache")
    func autoEQNilWhenProfileNotCached() throws {
        // Default AutoEQProfileManager has no profiles cached for "missing-id".
        // The pre-activate synchronous lookup must return nil so that
        // ensureTapExists falls through to the async resolve branch.
        let fix = makeFixture(supportsAutoEQ: true)
        fix.settings.setAutoEQSelection(
            for: fix.device.uid,
            to: AutoEQSelection(profileID: "missing-id", isEnabled: true)
        )

        fix.engine.setDevice(for: fix.app, deviceUID: fix.device.uid)

        let snap = try #require(capturedInitial(fix))
        #expect(snap.autoEQProfileID == nil)
    }

    // MARK: Ordering / post-activation behaviour

    @Test("activate(initial:) is the first event the controller observes")
    func activateIsFirstEvent() throws {
        let fix = makeFixture()
        fix.engine.setDevice(for: fix.app, deviceUID: fix.device.uid)

        let tap = try #require(fix.lastTap())
        let firstEvent = try #require(tap.events.first)
        if case .activate = firstEvent {
            // ok
        } else {
            Issue.record("First event was \(firstEvent), expected .activate")
        }
    }

    @Test("No EQ/AutoEQ/Loudness mutation runs BEFORE activate(initial:) — the apply-initial-state contract")
    func noMutationBeforeActivate() throws {
        // The core PR-1 invariant: every processor-state knob the audio thread
        // can observe must be set via TapInitialState, not via post-construction
        // calls that race with AudioDeviceStart. We assert this by checking
        // that no .updateEQSettings / .updateAutoEQProfile / .setAutoEQPreampEnabled
        // / .updateLoudnessCompensation / .updateLoudnessEqualization is recorded
        // BEFORE the .activate event in the tap's event log.
        //
        // Exercises a realistic config (AutoEQ-capable device with an enabled
        // selection whose profile is uncached) so applyAutoEQToTap runs
        // post-activate — proving the engine's fallback path doesn't accidentally
        // fire before activate.
        let fix = makeFixture(supportsAutoEQ: true)
        fix.settings.setAutoEQSelection(
            for: fix.device.uid,
            to: AutoEQSelection(profileID: "missing-id", isEnabled: true)
        )
        let custom = EQSettings(bandGains: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1], isEnabled: true)
        fix.settings.setEQSettings(custom, for: fix.app.persistenceIdentifier)
        var s = fix.settings.appSettings
        s.loudnessCompensationEnabled = true
        s.loudnessEqualizationEnabled = true
        fix.settings.updateAppSettings(s)

        fix.engine.setDevice(for: fix.app, deviceUID: fix.device.uid)

        let tap = try #require(fix.lastTap())
        let activateIndex = try #require(tap.events.firstIndex { event in
            if case .activate = event { return true }
            return false
        })

        for event in tap.events.prefix(activateIndex) {
            switch event {
            case .updateEQSettings, .updateAutoEQProfile, .setAutoEQPreampEnabled,
                 .updateLoudnessCompensation, .updateLoudnessEqualization:
                Issue.record("Pre-activate mutation breaks the apply-initial-state contract: \(event)")
            case .activate, .invalidate:
                break
            }
        }
    }

    @Test("Cache-miss AutoEQ: applyAutoEQToTap fires its sync nil-set after activate")
    func cacheMissTriggersPostActivateNilSet() throws {
        // Device supports AutoEQ + selection is enabled but profile is missing
        // from cache → ensureTapExists calls applyAutoEQToTap, which sets the
        // profile to nil synchronously before kicking off async resolution.
        // Verifies the engine's fallback path is reached when (and only when)
        // the synchronous pre-activate lookup misses.
        let fix = makeFixture(supportsAutoEQ: true)
        fix.settings.setAutoEQSelection(
            for: fix.device.uid,
            to: AutoEQSelection(profileID: "missing-id", isEnabled: true)
        )

        fix.engine.setDevice(for: fix.app, deviceUID: fix.device.uid)

        let tap = try #require(fix.lastTap())
        // The first event must still be .activate (apply-initial-state ordering)
        if case .activate = tap.events.first {
            // ok
        } else {
            Issue.record("activate(initial:) was not first event")
        }
        // A post-activate updateAutoEQProfile(nil) must be present from
        // applyAutoEQToTap's sync nil-set on cache miss.
        let postActivateAutoEQ = tap.events.dropFirst().compactMap { event -> String?? in
            if case let .updateAutoEQProfile(id) = event { return Optional(id) }
            return nil
        }
        #expect(postActivateAutoEQ.contains(where: { $0 == nil }))
    }
}

// MARK: - Helpers

@MainActor
private func capturedInitial(_ fix: Fixture) -> RecordingProcessTapController.TapInitialStateSnapshot? {
    guard let tap = fix.lastTap() else { return nil }
    for event in tap.events {
        if case let .activate(snapshot) = event { return snapshot }
    }
    return nil
}

// MARK: - Mock contract

@Suite("RecordingProcessTapController — protocol contract")
@MainActor
struct RecordingProcessTapControllerContractTests {
    @Test("Mock records activate, then mutation events, in invocation order")
    func recordsCallOrder() throws {
        let app = AudioApp(
            id: 1,
            processObjectIDs: [],
            name: "X",
            icon: NSImage(),
            bundleID: "com.x"
        )
        let tap = RecordingProcessTapController(app: app, deviceUIDs: ["uid"])

        try tap.activate(initial: TapInitialState())
        tap.updateEQSettings(EQSettings.flat)
        tap.updateAutoEQProfile(nil)

        #expect(tap.events.count == 3)
        if case .activate = tap.events[0] {} else { Issue.record("expected .activate at 0") }
        if case .updateEQSettings = tap.events[1] {} else { Issue.record("expected .updateEQSettings at 1") }
        if case .updateAutoEQProfile = tap.events[2] {} else { Issue.record("expected .updateAutoEQProfile at 2") }
    }

    @Test("Default property values match real controller defaults")
    func defaultsMatchProductionController() {
        let app = AudioApp(
            id: 1,
            processObjectIDs: [],
            name: "X",
            icon: NSImage(),
            bundleID: "com.x"
        )
        let tap = RecordingProcessTapController(app: app, deviceUIDs: ["uid"])

        // ProcessTapController's nonisolated(unsafe) defaults from source.
        #expect(tap.volume == 1.0)
        #expect(tap.isMuted == false)
        #expect(tap.currentDeviceVolume == 1.0)
        #expect(tap.isDeviceMuted == false)
        #expect(tap.audioLevel == 0.0)
        #expect(tap.tapSourceDeviceUID == nil)
        #expect(tap.currentDeviceUID == "uid")
    }

    @Test("Backward-compatible activate() convenience routes through activate(initial:)")
    func convenienceActivateRoutesThroughInitial() throws {
        let app = AudioApp(
            id: 1,
            processObjectIDs: [],
            name: "X",
            icon: NSImage(),
            bundleID: "com.x"
        )
        let tap = RecordingProcessTapController(app: app, deviceUIDs: ["uid"])

        // Convenience extension on the protocol: should funnel through activate(initial:)
        // with a default TapInitialState — proves no caller can sneak around the
        // initial-state contract by calling the old no-arg overload.
        try tap.activate()
        if case let .activate(snap) = tap.events.first {
            #expect(snap.autoEQProfileID == nil)
            #expect(snap.loudnessCompensationEnabled == false)
            #expect(snap.loudnessEqualizerSettings.enabled == false)
            #expect(snap.autoEQPreampEnabled == false)
            #expect(snap.eqSettings == EQSettings.flat)
            #expect(snap.loudnessVolume == 1.0)
        } else {
            Issue.record("activate() did not record an .activate event")
        }
    }
}
