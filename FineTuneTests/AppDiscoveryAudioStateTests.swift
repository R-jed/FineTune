import AppKit
import AudioToolbox
import Testing
@testable import FineTune

@MainActor
private final class AppDiscoveryProcessMonitorStub: AudioProcessMonitoring {
    var activeApps: [AudioApp]
    var onAppsChanged: (([AudioApp]) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(activeApps: [AudioApp] = []) {
        self.activeApps = activeApps
    }

    func start() {
        startCount += 1
    }

    func stop() {
        stopCount += 1
    }

    func setActiveApps(_ apps: [AudioApp]) {
        activeApps = apps
        onAppsChanged?(apps)
    }
}

@MainActor
private final class AppDiscoveryTapProbe {
    var creationCount = 0
    var lastTap: RecordingProcessTapController?
}

@MainActor
private struct AppDiscoveryFixture {
    let engine: AudioEngine
    let settings: SettingsManager
    let processMonitor: AppDiscoveryProcessMonitorStub
    let deviceMonitor: MockAudioDeviceMonitor
    let tapProbe: AppDiscoveryTapProbe
}

@MainActor
private func makeAppDiscoveryFixture(
    permissionStatus: AudioCapturePermissionStatus,
    apps: [AudioApp],
    devices: [AudioDevice]
) -> AppDiscoveryFixture {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    let settings = SettingsManager(directory: tempDir)

    let deviceMonitor = MockAudioDeviceMonitor()
    for device in devices {
        deviceMonitor.addOutputDevice(device)
    }

    let deviceVolume = MockDeviceVolumeProviding(deviceMonitor: deviceMonitor)
    if let firstDevice = devices.first {
        deviceVolume.defaultDeviceUID = firstDevice.uid
        deviceVolume.volumes[firstDevice.id] = 0.8
    }

    let processMonitor = AppDiscoveryProcessMonitorStub(activeApps: apps)
    let tapProbe = AppDiscoveryTapProbe()
    let permission = AudioRecordingPermission()
    permission.status = permissionStatus

    let engine = AudioEngine(
        permission: permission,
        settingsManager: settings,
        autoEQProfileManager: AutoEQProfileManager(),
        deviceProvider: deviceMonitor,
        processMonitor: processMonitor,
        deviceVolumeMonitor: deviceVolume,
        tapFactory: { app, uids, _ in
            tapProbe.creationCount += 1
            let tap = RecordingProcessTapController(app: app, deviceUIDs: uids)
            tapProbe.lastTap = tap
            return tap
        },
        startMonitorsAutomatically: false
    )

    return AppDiscoveryFixture(
        engine: engine,
        settings: settings,
        processMonitor: processMonitor,
        deviceMonitor: deviceMonitor,
        tapProbe: tapProbe
    )
}

@Suite("App discovery and audio-state separation")
@MainActor
struct AppDiscoveryAudioStateTests {
    private func quietApp() -> AudioApp {
        AudioApp(
            id: 42001,
            processObjectIDs: [],
            name: "Quiet Player",
            icon: NSImage(),
            bundleID: "com.test.quiet-player",
            isAudioActive: false
        )
    }

    private func readyApp(from quiet: AudioApp, objectID: AudioObjectID, helperBacked: Bool = false) -> AudioApp {
        AudioApp(
            id: quiet.id,
            processObjectIDs: [objectID],
            name: quiet.name,
            icon: quiet.icon,
            bundleID: quiet.bundleID,
            isHelperBacked: helperBacked,
            isAudioActive: true
        )
    }

    private func outputDevice(id: AudioDeviceID, uid: String, name: String) -> AudioDevice {
        AudioDevice(
            id: id,
            uid: uid,
            name: name,
            icon: nil,
            supportsAutoEQ: false
        )
    }

    @Test("App discovery starts even when capture permission is denied")
    func processMonitorStartsWithoutCapturePermission() {
        let device = outputDevice(id: 7101, uid: "uid-a", name: "Output A")
        let fix = makeAppDiscoveryFixture(
            permissionStatus: .denied,
            apps: [],
            devices: [device]
        )

        fix.engine.start()

        #expect(fix.processMonitor.startCount == 1)
        #expect(fix.tapProbe.creationCount == 0)
        fix.engine.stop()
    }

    @Test("EQ changes persist before a Core Audio process object exists")
    func eqPersistsWithoutTap() {
        let app = quietApp()
        let device = outputDevice(id: 7101, uid: "uid-a", name: "Output A")
        let fix = makeAppDiscoveryFixture(
            permissionStatus: .authorized,
            apps: [app],
            devices: [device]
        )
        let customEQ = EQSettings(
            bandGains: [2, 1, 0, -1, -2, 0, 1, 2, 1, 0],
            isEnabled: true
        )

        fix.engine.setEQSettings(customEQ, for: app)

        #expect(fix.settings.getEQSettings(for: app.persistenceIdentifier) == customEQ)
        #expect(fix.tapProbe.creationCount == 0)
    }

    @Test("Quiet follow-default app stays lazy until a Core Audio process object exists")
    func quietFollowDefaultAppDoesNotPrearm() {
        let quiet = quietApp()
        let device = outputDevice(id: 7101, uid: "uid-a", name: "Output A")
        let fix = makeAppDiscoveryFixture(
            permissionStatus: .authorized,
            apps: [quiet],
            devices: [device]
        )

        fix.engine.applyPersistedSettings()

        #expect(fix.engine.isFollowingDefault(for: quiet))
        #expect(fix.tapProbe.creationCount == 0)
    }

    @Test("Dormant Core Audio process object keeps an explicit route armed before first audio")
    func dormantProcessObjectPrewarmsExplicitRoute() throws {
        let dormant = AudioApp(
            id: 42002,
            processObjectIDs: [AudioObjectID(9001)],
            name: "Menu Bar Player",
            icon: NSImage(),
            bundleID: "com.test.menu-bar-player",
            isAudioActive: false
        )
        let deviceA = outputDevice(id: 7101, uid: "uid-a", name: "Output A")
        let deviceB = outputDevice(id: 7102, uid: "uid-b", name: "Output B")
        let fix = makeAppDiscoveryFixture(
            permissionStatus: .authorized,
            apps: [dormant],
            devices: [deviceA, deviceB]
        )
        fix.settings.setDeviceRouting(for: dormant.persistenceIdentifier, deviceUID: deviceB.uid)

        fix.engine.applyPersistedSettings()

        let tap = try #require(fix.tapProbe.lastTap)
        #expect(fix.tapProbe.creationCount == 1)
        #expect(tap.app.processObjectIDs == dormant.processObjectIDs)
        #expect(tap.currentDeviceUIDs == [deviceB.uid])
        #expect(fix.engine.getDeviceUID(for: dormant) == deviceB.uid)
    }

    @Test("Transient process-object disappearance keeps the explicit-route tap alive")
    func transientProcessObjectDisappearanceKeepsExplicitTap() throws {
        let quiet = quietApp()
        let active = readyApp(from: quiet, objectID: AudioObjectID(9001))
        let deviceA = outputDevice(id: 7101, uid: "uid-a", name: "Output A")
        let deviceB = outputDevice(id: 7102, uid: "uid-b", name: "Output B")
        let fix = makeAppDiscoveryFixture(
            permissionStatus: .authorized,
            apps: [active],
            devices: [deviceA, deviceB]
        )
        fix.settings.setDeviceRouting(for: active.persistenceIdentifier, deviceUID: deviceB.uid)

        fix.engine.applyPersistedSettings()
        let originalTap = try #require(fix.tapProbe.lastTap)
        #expect(originalTap.currentDeviceUIDs == [deviceB.uid])

        fix.processMonitor.setActiveApps([quiet])

        #expect(fix.tapProbe.creationCount == 1)
        #expect(fix.tapProbe.lastTap === originalTap)
        #expect(!originalTap.events.contains(.invalidate))
        #expect(originalTap.currentDeviceUIDs == [deviceB.uid])
        #expect(fix.engine.getDeviceUID(for: quiet) == deviceB.uid)

        let replacement = readyApp(from: quiet, objectID: AudioObjectID(9002))
        fix.processMonitor.setActiveApps([replacement])

        #expect(originalTap.events.contains(.invalidate))
        #expect(fix.tapProbe.creationCount == 2)
        let replacementTap = try #require(fix.tapProbe.lastTap)
        #expect(replacementTap !== originalTap)
        #expect(replacementTap.app.processObjectIDs == replacement.processObjectIDs)
        #expect(replacementTap.currentDeviceUIDs == [deviceB.uid])
        #expect(fix.engine.getDeviceUID(for: replacement) == deviceB.uid)
    }

    @Test("Choosing the current default as an explicit route provisions at the earliest supported point")
    func sameTargetExplicitSelectionProvisionsQuietApp() throws {
        let quiet = quietApp()
        let device = outputDevice(id: 7101, uid: "uid-b", name: "Output B")
        let fix = makeAppDiscoveryFixture(
            permissionStatus: .authorized,
            apps: [quiet],
            devices: [device]
        )

        fix.engine.applyPersistedSettings()
        #expect(fix.tapProbe.creationCount == 0)

        fix.engine.setDevice(for: quiet, deviceUID: device.uid)
        #expect(!fix.engine.isFollowingDefault(for: quiet))

        if #available(macOS 26.0, *) {
            let tap = try #require(fix.tapProbe.lastTap)
            #expect(fix.tapProbe.creationCount == 1)
            #expect(tap.app.processObjectIDs.isEmpty)
            #expect(tap.currentDeviceUIDs == [device.uid])
        } else {
            #expect(fix.tapProbe.creationCount == 0)
            let ready = readyApp(from: quiet, objectID: AudioObjectID(9001))
            fix.processMonitor.setActiveApps([ready])
            let tap = try #require(fix.tapProbe.lastTap)
            #expect(fix.tapProbe.creationCount == 1)
            #expect(tap.app.processObjectIDs == ready.processObjectIDs)
            #expect(tap.currentDeviceUIDs == [device.uid])
        }
    }

    @Test("Saved explicit route uses bundle prearm on macOS 26 and process-object provisioning earlier")
    func explicitRouteUsesBestAvailableProvisioning() throws {
        let quiet = quietApp()
        let deviceA = outputDevice(id: 7101, uid: "uid-a", name: "Output A")
        let deviceB = outputDevice(id: 7102, uid: "uid-b", name: "Output B")
        let fix = makeAppDiscoveryFixture(
            permissionStatus: .authorized,
            apps: [quiet],
            devices: [deviceA, deviceB]
        )
        fix.settings.setDeviceRouting(for: quiet.persistenceIdentifier, deviceUID: deviceB.uid)

        fix.engine.applyPersistedSettings()
        let ready = readyApp(from: quiet, objectID: AudioObjectID(9001))

        if #available(macOS 26.0, *) {
            let prearmedTap = try #require(fix.tapProbe.lastTap)
            #expect(fix.tapProbe.creationCount == 1)
            #expect(prearmedTap.app.processObjectIDs.isEmpty)
            #expect(prearmedTap.currentDeviceUIDs == [deviceB.uid])

            fix.processMonitor.setActiveApps([ready])

            #expect(fix.tapProbe.creationCount == 1)
            #expect(fix.tapProbe.lastTap === prearmedTap)
            #expect(!prearmedTap.events.contains(.invalidate))
        } else {
            #expect(fix.tapProbe.creationCount == 0)
            fix.processMonitor.setActiveApps([ready])
            let tap = try #require(fix.tapProbe.lastTap)
            #expect(fix.tapProbe.creationCount == 1)
            #expect(tap.app.processObjectIDs == ready.processObjectIDs)
            #expect(tap.currentDeviceUIDs == [deviceB.uid])
        }

        #expect(fix.engine.getDeviceUID(for: ready) == deviceB.uid)
    }

    @Test("Saved multi-device route uses the earliest platform-supported provisioning")
    func multiDeviceStateUsesBestAvailableProvisioning() throws {
        let quiet = quietApp()
        let deviceA = outputDevice(id: 7101, uid: "uid-a", name: "Output A")
        let deviceB = outputDevice(id: 7102, uid: "uid-b", name: "Output B")
        let fix = makeAppDiscoveryFixture(
            permissionStatus: .authorized,
            apps: [quiet],
            devices: [deviceA, deviceB]
        )
        let selectedUIDs: Set<String> = [deviceA.uid, deviceB.uid]
        fix.settings.setDeviceSelectionMode(for: quiet.persistenceIdentifier, to: .multi)
        fix.settings.setSelectedDeviceUIDs(for: quiet.persistenceIdentifier, to: selectedUIDs)

        fix.engine.applyPersistedSettings()

        #expect(fix.engine.getDeviceSelectionMode(for: quiet) == .multi)
        #expect(fix.engine.getSelectedDeviceUIDs(for: quiet) == selectedUIDs)
        #expect(fix.engine.getDeviceUID(for: quiet) == deviceA.uid)
        #expect(fix.engine.displayableApps.map(\.id) == [quiet.persistenceIdentifier])

        let ready = readyApp(from: quiet, objectID: AudioObjectID(9001))
        if #available(macOS 26.0, *) {
            let prearmedTap = try #require(fix.tapProbe.lastTap)
            #expect(fix.tapProbe.creationCount == 1)
            #expect(prearmedTap.app.processObjectIDs.isEmpty)
            #expect(prearmedTap.currentDeviceUIDs == [deviceA.uid, deviceB.uid])

            fix.processMonitor.setActiveApps([ready])

            #expect(fix.tapProbe.creationCount == 1)
            #expect(fix.tapProbe.lastTap === prearmedTap)
            #expect(!prearmedTap.events.contains(.invalidate))
        } else {
            #expect(fix.tapProbe.creationCount == 0)
            fix.processMonitor.setActiveApps([ready])
            let tap = try #require(fix.tapProbe.lastTap)
            #expect(fix.tapProbe.creationCount == 1)
            #expect(tap.app.processObjectIDs == ready.processObjectIDs)
            #expect(tap.currentDeviceUIDs == [deviceA.uid, deviceB.uid])
        }
    }

    @Test("Helper ownership uses process targeting and retires a bundle prearm when one exists")
    func helperOwnershipFallsBackToProcessTargeting() throws {
        let quiet = quietApp()
        let deviceA = outputDevice(id: 7101, uid: "uid-a", name: "Output A")
        let deviceB = outputDevice(id: 7102, uid: "uid-b", name: "Output B")
        let fix = makeAppDiscoveryFixture(
            permissionStatus: .authorized,
            apps: [quiet],
            devices: [deviceA, deviceB]
        )
        fix.settings.setDeviceRouting(for: quiet.persistenceIdentifier, deviceUID: deviceB.uid)
        fix.engine.applyPersistedSettings()
        let prearmedTap = fix.tapProbe.lastTap

        let helperReady = readyApp(
            from: quiet,
            objectID: AudioObjectID(9002),
            helperBacked: true
        )
        fix.processMonitor.setActiveApps([helperReady])

        if #available(macOS 26.0, *) {
            let prearmedTap = try #require(prearmedTap)
            #expect(prearmedTap.events.contains(.invalidate))
            #expect(fix.tapProbe.creationCount == 2)
            let replacementTap = try #require(fix.tapProbe.lastTap)
            #expect(replacementTap !== prearmedTap)
            #expect(replacementTap.app.processObjectIDs == helperReady.processObjectIDs)
            #expect(replacementTap.app.isHelperBacked)
            #expect(replacementTap.currentDeviceUIDs == [deviceB.uid])
        } else {
            #expect(prearmedTap == nil)
            #expect(fix.tapProbe.creationCount == 1)
            let tap = try #require(fix.tapProbe.lastTap)
            #expect(tap.app.processObjectIDs == helperReady.processObjectIDs)
            #expect(tap.app.isHelperBacked)
            #expect(tap.currentDeviceUIDs == [deviceB.uid])
        }
    }
}
