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

    @Test("Saved multi-device state is visible before tap creation and provisions when audio becomes ready")
    func multiDeviceStateRestoresBeforeTapExists() throws {
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
        #expect(fix.tapProbe.creationCount == 0)

        let ready = AudioApp(
            id: quiet.id,
            processObjectIDs: [AudioObjectID(9001)],
            name: quiet.name,
            icon: quiet.icon,
            bundleID: quiet.bundleID,
            isAudioActive: true
        )
        fix.processMonitor.setActiveApps([ready])

        let tap = try #require(fix.tapProbe.lastTap)
        #expect(tap.app.processObjectIDs == ready.processObjectIDs)
        #expect(tap.currentDeviceUIDs == [deviceA.uid, deviceB.uid])
    }
}
