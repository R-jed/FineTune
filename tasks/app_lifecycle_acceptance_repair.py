from pathlib import Path
import re


def read(path: str) -> str:
    return Path(path).read_text()


def write(path: str, text: str) -> None:
    Path(path).write_text(text)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)


path = "FineTune/Audio/Monitors/AudioProcessMonitor.swift"
s = read(path)
s = replace_once(s, """private struct AppFingerprint: Hashable {
    let pid: pid_t
    let objectIDs: [AudioObjectID]
    let isAudioActive: Bool
}
""", """private struct AppFingerprint: Hashable {
    let pid: pid_t
    let persistenceIdentifier: String
    let objectIDs: [AudioObjectID]
    let isHelperBacked: Bool
    let isAudioActive: Bool
}
""", "AppFingerprint fields")
s = replace_once(s, """            let oldSet = Set(activeApps.map {
                AppFingerprint(pid: $0.id, objectIDs: $0.processObjectIDs, isAudioActive: $0.isAudioActive)
            })
            let newSet = Set(sorted.map {
                AppFingerprint(pid: $0.id, objectIDs: $0.processObjectIDs, isAudioActive: $0.isAudioActive)
            })
""", """            let oldSet = Set(activeApps.map {
                AppFingerprint(
                    pid: $0.id,
                    persistenceIdentifier: $0.persistenceIdentifier,
                    objectIDs: $0.processObjectIDs,
                    isHelperBacked: $0.isHelperBacked,
                    isAudioActive: $0.isAudioActive
                )
            })
            let newSet = Set(sorted.map {
                AppFingerprint(
                    pid: $0.id,
                    persistenceIdentifier: $0.persistenceIdentifier,
                    objectIDs: $0.processObjectIDs,
                    isHelperBacked: $0.isHelperBacked,
                    isAudioActive: $0.isAudioActive
                )
            })
""", "AppFingerprint construction")
write(path, s)

path = "FineTune/Settings/SettingsManager.swift"
s = read(path)
s = replace_once(s, """    func ignoreApp(_ identifier: String, info: IgnoredAppInfo) {
        settings.ignoredApps.insert(identifier)
        settings.ignoredAppInfo[identifier] = info
        // Hiding is mutually exclusive with pinning
        settings.pinnedApps.remove(identifier)
        settings.pinnedAppInfo.removeValue(forKey: identifier)
        // Clear per-app settings — FineTune won't interact with this app
        settings.appVolumes.removeValue(forKey: identifier)
        settings.appBoosts.removeValue(forKey: identifier)
        settings.appMutes.removeValue(forKey: identifier)
        settings.appDeviceRouting.removeValue(forKey: identifier)
        settings.appEQSettings.removeValue(forKey: identifier)
        settings.appDeviceSelectionMode.removeValue(forKey: identifier)
        settings.appSelectedDeviceUIDs.removeValue(forKey: identifier)
        scheduleSave()
    }
""", """    func ignoreApp(_ identifier: String, info: IgnoredAppInfo) {
        settings.ignoredApps.insert(identifier)
        settings.ignoredAppInfo[identifier] = info
        scheduleSave()
    }
""", "reversible hide")
write(path, s)

path = "FineTune/Audio/Engine/AudioEngine.swift"
s = read(path)
s = replace_once(s, """    private var pendingCleanup: [pid_t: Task<Void, Never>] = [:]  // Grace period for stale tap cleanup
    private var staleCleanupTask: Task<Void, Never>?  // Debounced cleanup scheduling
    private let unpinRemovalDelay: Duration
    private var autoHideWhenSilent: [String: PinnedAppInfo] = [:]
    private var visibleDuringUnpinGrace: Set<String> = []
    private var hiddenAfterUnpin: Set<String> = []
    private var pendingUnpinRemoval: [String: Task<Void, Never>] = [:]
    private var healthMonitorTask: Task<Void, Never>?  // Periodic tap health monitor
""", """    private var pendingCleanup: [pid_t: Task<Void, Never>] = [:]  // Grace period for stale tap cleanup
    private var staleCleanupTask: Task<Void, Never>?  // Debounced cleanup scheduling
    private var healthMonitorTask: Task<Void, Never>?  // Periodic tap health monitor
""", "remove obsolete unpin state")
s = replace_once(s, """        isAlive: ((AudioDeviceID) -> Bool)? = nil,
        unpinRemovalDelay: Duration = .seconds(10),
        startMonitorsAutomatically: Bool = true
""", """        isAlive: ((AudioDeviceID) -> Bool)? = nil,
        startMonitorsAutomatically: Bool = true
""", "remove unpin delay init parameter")
s = replace_once(s, """        self.volumeState = VolumeState(settingsManager: manager)
        self.isAliveCheck = isAlive ?? { $0.isDeviceAlive() }
        self.unpinRemovalDelay = unpinRemovalDelay
""", """        self.volumeState = VolumeState(settingsManager: manager)
        self.isAliveCheck = isAlive ?? { $0.isDeviceAlive() }
""", "remove unpin delay assignment")
s = replace_once(s, """        processMonitor.onAppsChanged = { [weak self] apps in
            self?.invalidateTapsWithChangedProcesses(apps)
            self?.updateUnpinnedAppVisibility(apps)
            self?.applyPersistedSettings()
            self?.scheduleStaleCleanup()
        }
""", """        processMonitor.onAppsChanged = { [weak self] apps in
            self?.invalidateTapsWithChangedProcesses(apps)
            self?.applyPersistedSettings()
            self?.scheduleStaleCleanup()
        }
""", "remove unpin visibility callback")
s = replace_once(s, """        let activeApps = apps
            .filter { !appListCoordinator.isIgnored(identifier: $0.persistenceIdentifier) }
            .filter { !hiddenAfterUnpin.contains($0.persistenceIdentifier) }
        let activeAppsByIdentifier = Dictionary(
            activeApps.map { ($0.persistenceIdentifier, $0) },
            uniquingKeysWith: { $0.merging($1) }
        )
        let activeIdentifiers = Set(activeAppsByIdentifier.keys)
        let graceApps = autoHideWhenSilent.values.filter {
            visibleDuringUnpinGrace.contains($0.persistenceIdentifier)
        }
        let inactivePinned = (appListCoordinator.pinnedAppInfo() + graceApps)
            .filter { !activeIdentifiers.contains($0.persistenceIdentifier) }
            .map { DisplayableApp.pinnedInactive($0) }
""", """        let activeApps = apps
            .filter { !appListCoordinator.isIgnored(identifier: $0.persistenceIdentifier) }
        let activeAppsByIdentifier = Dictionary(
            activeApps.map { ($0.persistenceIdentifier, $0) },
            uniquingKeysWith: { $0.merging($1) }
        )
        let activeIdentifiers = Set(activeAppsByIdentifier.keys)
        let inactivePinned = appListCoordinator.pinnedAppInfo()
            .filter { !activeIdentifiers.contains($0.persistenceIdentifier) }
            .filter { !appListCoordinator.isIgnored(identifier: $0.persistenceIdentifier) }
            .map { DisplayableApp.pinnedInactive($0) }
""", "simplify displayable app semantics")
s = replace_once(s, """    func pinApp(_ app: AudioApp) {
        clearUnpinVisibilityState(app.persistenceIdentifier)
        appListCoordinator.pinApp(app)
    }
""", """    func pinApp(_ app: AudioApp) {
        appListCoordinator.pinApp(app)
    }
""", "active pin cleanup")
s = replace_once(s, """    func pinApp(_ info: PinnedAppInfo) {
        clearUnpinVisibilityState(info.persistenceIdentifier)
        appListCoordinator.pinApp(info)
        applyPersistedSettings()
    }
""", """    func pinApp(_ info: PinnedAppInfo) {
        appListCoordinator.pinApp(info)
        applyPersistedSettings()
    }
""", "inactive pin cleanup")
pattern = re.compile(r"    /// Unpin an app by its persistence identifier\.\n    func unpinApp\(_ identifier: String\) \{.*?\n    func moveApp\(_ identifier: String, to targetIdentifier: String\) \{", re.S)
replacement = """    /// Unpin an app by its persistence identifier. Running apps remain visible.
    /// Pinning only controls whether the row persists after the process exits.
    func unpinApp(_ identifier: String) {
        appListCoordinator.unpinApp(identifier)
    }

    func moveApp(_ identifier: String, to targetIdentifier: String) {"""
s, count = pattern.subn(replacement, s, count=1)
if count != 1:
    raise SystemExit(f"clean-break unpin state machine: expected 1 match, found {count}")
s = replace_once(s, """    func ignoreApp(_ app: AudioApp) {
        appListCoordinator.recordIgnore(app)

        if let tap = taps.removeValue(forKey: app.id) {
            tap.invalidate()
        }
        appDeviceRouting.removeValue(forKey: app.id)
        followsDefault.remove(app.id)
        appliedPIDs.remove(app.id)
    }
""", """    func ignoreApp(_ app: AudioApp) {
        appListCoordinator.recordIgnore(app)
        retireTap(for: app.id, resetRuntimeState: true)
    }
""", "active hide runtime teardown")
s = replace_once(s, """    private func invalidateTapsWithChangedProcesses(_ apps: [AudioApp]) {
        for app in apps {
            guard let tap = taps[app.id],
                  Set(tap.app.processObjectIDs) != Set(app.processObjectIDs) else { continue }
            logger.info("Invalidating tap for \\(app.name, privacy: .public) PID \\(app.id): process objects changed from \\(tap.app.processObjectIDs.description, privacy: .public) to \\(app.processObjectIDs.description, privacy: .public)")
            taps.removeValue(forKey: app.id)?.invalidate()
            appliedPIDs.remove(app.id)
        }
    }
""", """    private func invalidateTapsWithChangedProcesses(_ apps: [AudioApp]) {
        let appsByPID = Dictionary(
            apps.map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        let liveIdentifiers = Set(apps.map(\\.persistenceIdentifier))

        for (pid, tap) in Array(taps) {
            if let app = appsByPID[pid] {
                let identityChanged = app.persistenceIdentifier != tap.app.persistenceIdentifier
                let processObjectsChanged = Set(app.processObjectIDs) != Set(tap.app.processObjectIDs)
                guard identityChanged || processObjectsChanged else { continue }

                logger.info("Retiring tap for PID \\(pid): app identity or process objects changed")
                retireTap(for: pid, resetRuntimeState: identityChanged)
            } else if liveIdentifiers.contains(tap.app.persistenceIdentifier) {
                logger.info("Retiring tap for PID \\(pid): representative PID moved")
                retireTap(for: pid, resetRuntimeState: true)
            }
        }
    }

    private func retireTap(for pid: pid_t, resetRuntimeState: Bool) {
        pendingCleanup.removeValue(forKey: pid)?.cancel()
        taps.removeValue(forKey: pid)?.invalidate()
        appliedPIDs.remove(pid)

        guard resetRuntimeState else { return }
        appDeviceRouting.removeValue(forKey: pid)
        followsDefault.remove(pid)
        volumeState.removeVolume(for: pid)
        tapRecoveryCooldownUntil.removeValue(forKey: pid)
    }
""", "tap identity retirement")
write(path, s)

path = "FineTuneTests/AudioEngineTapInitialStateTests.swift"
s = read(path)
s = replace_once(s, """private func makeFixture(
    supportsAutoEQ: Bool = true,
    deviceVolume: Float = 0.75,
    unpinRemovalDelay: Duration = .seconds(10)
) -> Fixture {
""", """private func makeFixture(
    supportsAutoEQ: Bool = true,
    deviceVolume: Float = 0.75
) -> Fixture {
""", "test fixture unpin delay")
s = replace_once(s, """        },
        unpinRemovalDelay: unpinRemovalDelay,
        startMonitorsAutomatically: false
""", """        },
        startMonitorsAutomatically: false
""", "test engine init unpin delay")
s = replace_once(s, "let fix = makeFixture(unpinRemovalDelay: .zero)", "let fix = makeFixture()", "quiet unpin test fixture")
s = replace_once(s, """    func hideRestorePreservesInactivePinnedApp() {
        let fix = makeFixture()
        let info = PinnedAppInfo(
""", """    func hideRestorePreservesInactivePinnedApp() {
        let fix = makeFixture()
        fix.processMonitor.activeApps = []
        let info = PinnedAppInfo(
""", "inactive hide restore fixture")
write(path, s)

Path("FineTuneTests/AudioAppIdentityTests.swift").write_text("""import AppKit
import AudioToolbox
import Testing
@testable import FineTune

@Suite("AudioApp runtime identity")
struct AudioAppIdentityTests {
    private func app(pid: pid_t, objectIDs: [AudioObjectID], bundleID: String, active: Bool) -> AudioApp {
        AudioApp(
            id: pid,
            processObjectIDs: objectIDs,
            name: bundleID,
            icon: NSImage(),
            bundleID: bundleID,
            isAudioActive: active
        )
    }

    @Test("PID reuse by a different app is an observable identity change")
    func pidReuseChangesIdentity() {
        let old = app(pid: 42, objectIDs: [1], bundleID: "com.test.old", active: true)
        let replacement = app(pid: 42, objectIDs: [1], bundleID: "com.test.new", active: true)
        #expect(old != replacement)
    }

    @Test("Process object and activity changes are observable")
    func processStateChangesIdentity() {
        let original = app(pid: 42, objectIDs: [1], bundleID: "com.test.app", active: false)
        let changedObjects = app(pid: 42, objectIDs: [2], bundleID: "com.test.app", active: false)
        let active = app(pid: 42, objectIDs: [1], bundleID: "com.test.app", active: true)
        #expect(original != changedObjects)
        #expect(original != active)
    }
}
""")