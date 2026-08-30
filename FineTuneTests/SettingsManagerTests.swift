// FineTuneTests/SettingsManagerTests.swift
// Tests for SettingsManager.Settings JSON round-trip, merge algorithm, and pruning.
// Uses temp directories — no real settings files affected.

import Testing
import Foundation
@testable import FineTune

// MARK: - Pinned App Selection

@Suite("PinnedAppInfo — app bundle selection")
struct PinnedAppInfoSelectionTests {
    @Test("Valid app bundle produces stable pinned metadata")
    func validAppBundle() throws {
        let appURL = try makeAppBundle(
            displayName: "Example Player",
            bundleIdentifier: "com.example.player"
        )
        defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }

        let info = try #require(PinnedAppInfo(
            appURL: appURL,
            excludingBundleIdentifier: "com.finetuneapp.FineTune"
        ))

        #expect(info.persistenceIdentifier == "com.example.player")
        #expect(info.displayName == "Example Player")
        #expect(info.bundleID == "com.example.player")
    }

    @Test("Own, missing, and damaged app bundles are rejected")
    func rejectsInvalidBundles() throws {
        let ownAppURL = try makeAppBundle(
            displayName: "FineTune",
            bundleIdentifier: "com.finetuneapp.FineTune"
        )
        let root = ownAppURL.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(PinnedAppInfo(
            appURL: ownAppURL,
            excludingBundleIdentifier: "com.finetuneapp.FineTune"
        ) == nil)
        #expect(PinnedAppInfo(
            appURL: root.appendingPathComponent("Missing.app"),
            excludingBundleIdentifier: "com.finetuneapp.FineTune"
        ) == nil)

        let damagedURL = try makeAppBundle(
            displayName: "Broken",
            bundleIdentifier: "com.example.broken",
            includeExecutable: false
        )
        defer { try? FileManager.default.removeItem(at: damagedURL.deletingLastPathComponent()) }
        #expect(PinnedAppInfo(
            appURL: damagedURL,
            excludingBundleIdentifier: "com.finetuneapp.FineTune"
        ) == nil)
    }

    private func makeAppBundle(
        displayName: String,
        bundleIdentifier: String,
        includeExecutable: Bool = true
    ) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appURL = root.appendingPathComponent("Example.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "CFBundleDisplayName": displayName,
            "CFBundleExecutable": "Example",
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": "Example",
            "CFBundlePackageType": "APPL",
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: contentsURL.appendingPathComponent("Info.plist"))
        if includeExecutable {
            let executableURL = contentsURL
                .appendingPathComponent("MacOS", isDirectory: true)
                .appendingPathComponent("Example")
            try FileManager.default.createDirectory(
                at: executableURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            FileManager.default.createFile(atPath: executableURL.path, contents: Data())
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: executableURL.path
            )
        }
        return appURL
    }
}

@Suite("SettingsManager — pin persistence and placement")
@MainActor
struct AppPinSettingsTests {
    private func makeManager() -> SettingsManager {
        SettingsManager(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
        )
    }

    private func info(_ id: String = "com.example.player") -> PinnedAppInfo {
        PinnedAppInfo(
            persistenceIdentifier: id,
            displayName: "Example Player",
            bundleID: id
        )
    }

    @Test("Pinning is idempotent and preserves raw latent order")
    func pinningIsIdempotent() {
        let manager = makeManager()
        manager.ensureAppsInOrder(["normal", "com.example.player"])
        let pinned = info()

        manager.pinApp(pinned.persistenceIdentifier, info: pinned)
        manager.pinApp(pinned.persistenceIdentifier, info: pinned)

        #expect(manager.isPinned(pinned.persistenceIdentifier))
        #expect(manager.getPinnedAppInfo() == [pinned])
        #expect(manager.appOrder == ["normal", "com.example.player"])
    }

    @Test("Low-level pinning does not implicitly unhide")
    func pinDoesNotUnhide() {
        let manager = makeManager()
        let pinned = info()
        manager.ignoreApp(
            pinned.persistenceIdentifier,
            info: IgnoredAppInfo(
                persistenceIdentifier: pinned.persistenceIdentifier,
                displayName: pinned.displayName,
                bundleID: pinned.bundleID
            )
        )

        manager.pinApp(pinned.persistenceIdentifier, info: pinned)

        #expect(manager.isPinned(pinned.persistenceIdentifier))
        #expect(manager.isIgnored(pinned.persistenceIdentifier))
    }

    @Test("Explicit Add Applications intent unhides and pins atomically")
    func selectedAddUnhidesAndPins() {
        let manager = makeManager()
        let pinned = info()
        manager.ignoreApp(
            pinned.persistenceIdentifier,
            info: IgnoredAppInfo(
                persistenceIdentifier: pinned.persistenceIdentifier,
                displayName: pinned.displayName,
                bundleID: pinned.bundleID
            )
        )

        manager.addSelectedPinnedApp(
            pinned,
            visibleOrder: [pinned.persistenceIdentifier]
        )

        #expect(manager.isPinned(pinned.persistenceIdentifier))
        #expect(!manager.isIgnored(pinned.persistenceIdentifier))
        #expect(manager.appOrder == [pinned.persistenceIdentifier])
    }

    @Test("Placement commits membership without rewriting unrelated latent history")
    func placementCommitsOrderAndMembership() {
        let manager = makeManager()
        manager.ensureAppsInOrder(["A", "B", "C"])

        let changed = manager.placeApp(
            "C",
            visibleOrder: ["C", "A", "B"],
            pinned: true,
            info: info("C")
        )

        #expect(changed)
        #expect(manager.appOrder == ["A", "B", "C"])
        #expect(manager.isPinned("C"))
    }

    @Test("Cross-section placement preserves hidden latent anchors")
    func placementPreservesHiddenLatentAnchors() {
        let manager = makeManager()
        manager.ensureAppsInOrder(["P", "A", "B", "C", "hidden"])
        manager.pinApp("P", info: info("P"))

        _ = manager.placeApp(
            "C",
            visibleOrder: ["C", "P", "A", "B"],
            pinned: true,
            info: info("C")
        )

        #expect(manager.appOrder == ["C", "hidden", "P", "A", "B"])
        #expect(manager.isPinned("C"))
    }

    @Test("Cross-section placement does not flatten unrelated interleaved latent history")
    func placementPreservesInterleavedRawOrder() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        var stored = SettingsManager.Settings()
        stored.appOrder = ["P1", "A", "P2", "B"]
        stored.pinnedApps = ["P1", "P2"]
        stored.pinnedAppInfo = [
            "P1": info("P1"),
            "P2": info("P2"),
        ]
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(stored)
            .write(to: directory.appendingPathComponent("settings.json"))
        let manager = SettingsManager(directory: directory)

        _ = manager.placeApp(
            "B",
            visibleOrder: ["P1", "B", "P2", "A"],
            pinned: true,
            info: info("B")
        )

        #expect(manager.appOrder == ["P1", "A", "B", "P2"])
    }
}

@Suite("SettingsManager — global app order")
@MainActor
struct GlobalAppOrderSettingsTests {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeSettings(_ settings: SettingsManager.Settings, to directory: URL) throws {
        let data = try JSONEncoder().encode(settings)
        try data.write(to: directory.appendingPathComponent("settings.json"), options: .atomic)
    }

    @Test("visible app reorder seeds identifiers not yet in persisted order")
    func visibleAppOrderSeedsUnseenIdentifiers() {
        let manager = SettingsManager(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
        )
        let first = "com.example.first"
        let second = "com.example.second"
        let third = "com.example.third"

        manager.moveApp(third, to: first, currentOrder: [first, second, third])
        #expect(manager.appOrder == [third, first, second])

        manager.moveApp(third, to: second, currentOrder: [third, first, second])
        #expect(manager.appOrder == [first, second, third])
    }

    @Test("reordering visible apps preserves hidden and absent latent anchors")
    func visibleReorderPreservesLatentAnchors() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        var stored = SettingsManager.Settings()
        stored.appOrder = ["A", "hidden", "B", "C"]
        stored.ignoredApps = ["hidden"]
        try writeSettings(stored, to: directory)

        let manager = SettingsManager(directory: directory)
        manager.moveApp("A", to: "C", currentOrder: ["A", "B", "C"])

        #expect(manager.appOrder == ["B", "C", "A", "hidden"])
    }

    @Test("app order survives a real disk flush and manager recreation")
    func appOrderDiskRoundTrip() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = SettingsManager(directory: directory)
        first.moveApp("C", to: "A", currentOrder: ["A", "B", "C"])
        #expect(first.appOrder == ["C", "A", "B"])
        first.flushSync()

        let reloaded = SettingsManager(directory: directory)
        #expect(reloaded.appOrder == ["C", "A", "B"])
    }

    @Test("hidden apps retain default-valued persisted settings during pruning")
    func hiddenAppsSurvivePruning() {
        let manager = SettingsManager(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
        )
        let identifier = "com.example.hidden"
        manager.setVolume(for: identifier, to: 1.0)
        manager.ignoreApp(
            identifier,
            info: IgnoredAppInfo(
                persistenceIdentifier: identifier,
                displayName: "Hidden",
                bundleID: identifier
            )
        )

        manager.pruneStaleSettings(keeping: [])

        #expect(manager.getVolume(for: identifier) == 1.0)
        #expect(manager.isIgnored(identifier))
    }

    @Test("v12 pin fields decode as current pin state and seed order when absent")
    func v12PinFieldsDecode() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let json = """
        {
          "version": 12,
          "pinnedApps": ["com.example.z", "com.example.a"],
          "pinnedAppInfo": {}
        }
        """
        try Data(json.utf8).write(to: directory.appendingPathComponent("settings.json"))

        let manager = SettingsManager(directory: directory)
        let decoded = try JSONDecoder().decode(
            SettingsManager.Settings.self,
            from: Data(contentsOf: directory.appendingPathComponent("settings.json"))
        )

        #expect(manager.appOrder == ["com.example.a", "com.example.z"])
        #expect(manager.isPinned("com.example.a"))
        #expect(manager.isPinned("com.example.z"))
        #expect(decoded.version == 14)
    }

    @Test("v12 pin metadata cannot override an existing raw appOrder")
    func existingAppOrderWinsOverPins() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let json = """
        {
          "version": 12,
          "pinnedApps": ["legacy-z", "legacy-a"],
          "pinnedAppInfo": {},
          "appOrder": ["C", "A", "B"]
        }
        """
        try Data(json.utf8).write(to: directory.appendingPathComponent("settings.json"))

        let manager = SettingsManager(directory: directory)

        #expect(manager.appOrder == ["C", "A", "B"])
    }

    @Test("duplicate appOrder entries are normalized on decode")
    func duplicateAppOrderEntriesAreNormalized() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let json = """
        {
          "version": 12,
          "appOrder": ["B", "B", "A", "B"]
        }
        """
        try Data(json.utf8).write(to: directory.appendingPathComponent("settings.json"))

        let manager = SettingsManager(directory: directory)

        #expect(manager.appOrder == ["B", "A"])
    }

    @Test("resetting all settings clears the global app order")
    func resetClearsAppOrder() {
        let manager = SettingsManager(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
        )
        let pinned = PinnedAppInfo(
            persistenceIdentifier: "C",
            displayName: "Charlie",
            bundleID: "C"
        )
        manager.moveApp("C", to: "A", currentOrder: ["A", "B", "C"])
        manager.pinApp("C", info: pinned)
        #expect(!manager.appOrder.isEmpty)
        #expect(manager.isPinned("C"))

        manager.resetAllSettings()

        #expect(manager.appOrder.isEmpty)
        #expect(!manager.isPinned("C"))
        #expect(manager.getPinnedAppInfo().isEmpty)
    }
}

// MARK: - Settings JSON Round-Trip

@Suite("SettingsManager.Settings — JSON serialization")
@MainActor
struct SettingsJSONTests {

    @Test("Default Settings encodes and decodes to equal value")
    func defaultRoundTrip() throws {
        let original = SettingsManager.Settings()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SettingsManager.Settings.self, from: data)
        #expect(decoded.version == original.version)
        #expect(decoded.appVolumes == original.appVolumes)
        #expect(decoded.appMutes == original.appMutes)
        #expect(decoded.systemSoundsFollowsDefault == original.systemSoundsFollowsDefault)
    }

    @Test("Populated Settings round-trips all fields")
    func populatedRoundTrip() throws {
        var original = SettingsManager.Settings()
        original.appVolumes = ["com.test.app": 0.5]
        original.appMutes = ["com.test.app": true]
        original.appBoosts = ["com.test.app": 2.0]
        original.appDeviceRouting = ["com.test.app": "device-uid-123"]
        original.appOrder = ["com.test.second", "com.test.app"]
        original.pinnedApps = ["com.test.second"]
        original.pinnedAppInfo = [
            "com.test.second": PinnedAppInfo(
                persistenceIdentifier: "com.test.second",
                displayName: "Second",
                bundleID: "com.test.second"
            )
        ]
        original.outputDevicePriority = ["uid-a", "uid-b", "uid-c"]
        original.ddcVolumes = ["monitor-1": 75]
        original.ddcMuteStates = ["monitor-1": false]
        original.autoEQPreampEnabled = false
        original.hiddenOutputDeviceUIDs = ["uid-hidden-out-1", "uid-hidden-out-2"]
        original.deviceIconOverrides = ["uid-a": "airpodsmax", "uid-b": "gamecontroller.fill"]

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SettingsManager.Settings.self, from: data)

        #expect(decoded.appVolumes == original.appVolumes)
        #expect(decoded.appMutes == original.appMutes)
        #expect(decoded.appBoosts == original.appBoosts)
        #expect(decoded.appDeviceRouting == original.appDeviceRouting)
        #expect(decoded.appOrder == original.appOrder)
        #expect(decoded.pinnedApps == original.pinnedApps)
        #expect(decoded.pinnedAppInfo == original.pinnedAppInfo)
        #expect(decoded.outputDevicePriority == original.outputDevicePriority)
        #expect(decoded.ddcVolumes == original.ddcVolumes)
        #expect(decoded.ddcMuteStates == original.ddcMuteStates)
        #expect(decoded.autoEQPreampEnabled == false)
        #expect(decoded.hiddenOutputDeviceUIDs == original.hiddenOutputDeviceUIDs)
        #expect(decoded.deviceIconOverrides == original.deviceIconOverrides)
    }


    @Test("v14 encoding persists current pin fields")
    func v14EncodingPersistsPinFields() throws {
        var settings = SettingsManager.Settings()
        settings.appOrder = ["B", "A"]
        settings.pinnedApps = ["B"]
        settings.pinnedAppInfo = [
            "B": PinnedAppInfo(
                persistenceIdentifier: "B",
                displayName: "Bravo",
                bundleID: "B"
            )
        ]

        let data = try JSONEncoder().encode(settings)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["version"] as? Int == 14)
        #expect(object["appOrder"] as? [String] == ["B", "A"])
        #expect((object["pinnedApps"] as? [String]) == ["B"])
        #expect(object["pinnedAppInfo"] != nil)
    }

    @Test("v13 settings without pin fields decode to empty current pin state")
    func v13WithoutPinsDefaultsEmpty() throws {
        let json = #"{"version":13,"appOrder":["B","A"]}"#
        let decoded = try JSONDecoder().decode(SettingsManager.Settings.self, from: Data(json.utf8))

        #expect(decoded.version == 14)
        #expect(decoded.appOrder == ["B", "A"])
        #expect(decoded.pinnedApps.isEmpty)
        #expect(decoded.pinnedAppInfo.isEmpty)
    }

    @Test("Decoding empty JSON produces valid defaults")
    func emptyJSONDefaults() throws {
        let json = "{}"
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(SettingsManager.Settings.self, from: data)
        #expect(decoded.version == 14)
        #expect(decoded.appVolumes.isEmpty)
        #expect(decoded.appMutes.isEmpty)
        #expect(decoded.systemSoundsFollowsDefault == true)
        #expect(decoded.autoEQPreampEnabled == true)
        #expect(decoded.hiddenOutputDeviceUIDs.isEmpty)
        #expect(decoded.deviceIconOverrides.isEmpty)
    }

    @Test("Decoding with extra unknown keys is tolerated")
    func unknownKeysIgnored() throws {
        let json = """
        {"version": 9, "unknownField": "hello", "anotherNew": 42}
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(SettingsManager.Settings.self, from: data)
        #expect(decoded.version == 14)
    }

    @Test("Volume values above 1.0 are clamped to 1.0 on decode")
    func volumeClampedAboveOne() throws {
        let json = """
        {"appVolumes": {"com.test.app": 1.5, "com.other.app": 0.8}}
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(SettingsManager.Settings.self, from: data)
        #expect(decoded.appVolumes["com.test.app"] == 1.0)
        #expect(decoded.appVolumes["com.other.app"] == 0.8)
    }

    @Test("Negative volume values are filtered out on decode")
    func negativeVolumesFiltered() throws {
        let json = """
        {"appVolumes": {"com.test.app": -0.5, "com.good.app": 0.7}}
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(SettingsManager.Settings.self, from: data)
        #expect(decoded.appVolumes["com.test.app"] == nil, "Negative volume should be filtered out")
        #expect(decoded.appVolumes["com.good.app"] == 0.7)
    }

    @Test("Non-finite volume values cannot be encoded to JSON")
    func nonFiniteVolumesCannotEncode() throws {
        // JSON spec does not support NaN or Infinity.
        // JSONEncoder throws when encountering non-finite floats.
        // This verifies the boundary: production code's filter on decode handles
        // finite-but-invalid values (negative, >1.0); non-finite values are
        // prevented at the encoding layer.
        var settings = SettingsManager.Settings()
        settings.appVolumes["inf_app"] = Float.infinity

        #expect(throws: EncodingError.self) {
            _ = try JSONEncoder().encode(settings)
        }
    }

    @Test("Invalid defaultNewAppVolume is reset to 1.0 on decode")
    func invalidDefaultVolumeReset() throws {
        // AppSettings uses auto-synthesized Codable — all keys required.
        // MenuBarIconStyle raw value is capitalized ("Default", not "default").
        let json = """
        {"appSettings": {"launchAtLogin": false, "menuBarIconStyle": "Default", "defaultNewAppVolume": -5.0, "lockInputDevice": true, "showDeviceDisconnectAlerts": true}}
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(SettingsManager.Settings.self, from: data)
        #expect(decoded.appSettings.defaultNewAppVolume == 1.0,
                "Negative defaultNewAppVolume should be reset to 1.0")
    }
}

// MARK: - mergePriorityOrder

@Suite("SettingsManager — mergePriorityOrder algorithm")
@MainActor
struct MergePriorityOrderTests {

    @Test("No disconnected devices: returns connectedOrder as-is")
    func noDisconnected() {
        let old = ["A", "B", "C"]
        let connected = ["C", "A", "B"] // user reordered
        let result = SettingsManager.mergePriorityOrder(oldPriority: old, connectedOrder: connected)
        #expect(result == ["C", "A", "B"])
    }

    @Test("Disconnected device anchored between two connected devices")
    func disconnectedBetween() {
        let old = ["A", "D", "B"] // D is disconnected (not in connectedOrder)
        let connected = ["A", "B"]
        let result = SettingsManager.mergePriorityOrder(oldPriority: old, connectedOrder: connected)
        // D was after A in old, so anchored to A. Result: A, D, B
        #expect(result == ["A", "D", "B"])
    }

    @Test("Disconnected device at the beginning (no preceding connected device)")
    func disconnectedAtStart() {
        let old = ["D", "A", "B"] // D is disconnected, before all connected
        let connected = ["A", "B"]
        let result = SettingsManager.mergePriorityOrder(oldPriority: old, connectedOrder: connected)
        // D has nil anchor → inserted at front
        #expect(result == ["D", "A", "B"])
    }

    @Test("Multiple disconnected devices with same anchor")
    func multipleDisconnectedSameAnchor() {
        let old = ["A", "D1", "D2", "B"]
        let connected = ["A", "B"]
        let result = SettingsManager.mergePriorityOrder(oldPriority: old, connectedOrder: connected)
        #expect(result == ["A", "D1", "D2", "B"])
    }

    @Test("All devices disconnected: returns disconnected in old order")
    func allDisconnected() {
        let old = ["A", "B", "C"]
        let connected: [String] = []
        let result = SettingsManager.mergePriorityOrder(oldPriority: old, connectedOrder: connected)
        // All disconnected, anchored to nil → inserted at front in order
        #expect(result == ["A", "B", "C"])
    }

    @Test("Empty old priority: returns connectedOrder")
    func emptyOldPriority() {
        let result = SettingsManager.mergePriorityOrder(oldPriority: [], connectedOrder: ["X", "Y"])
        #expect(result == ["X", "Y"])
    }

    @Test("Both empty: returns empty")
    func bothEmpty() {
        let result = SettingsManager.mergePriorityOrder(oldPriority: [], connectedOrder: [])
        #expect(result.isEmpty)
    }

    @Test("Reordering connected devices preserves disconnected anchors")
    func reorderPreservesAnchors() {
        let old = ["A", "D1", "B", "D2", "C"]
        let connected = ["C", "A", "B"] // user moved C to front
        let result = SettingsManager.mergePriorityOrder(oldPriority: old, connectedOrder: connected)
        // D1 anchored to A, D2 anchored to B
        // Result: C, A, D1, B, D2
        #expect(result == ["C", "A", "D1", "B", "D2"])
    }

    @Test("Disconnected device at end (anchored to last connected)")
    func disconnectedAtEnd() {
        let old = ["A", "B", "D"]
        let connected = ["A", "B"]
        let result = SettingsManager.mergePriorityOrder(oldPriority: old, connectedOrder: connected)
        // D anchored to B → after B
        #expect(result == ["A", "B", "D"])
    }
}

// MARK: - AppSettings Defaults

@Suite("AppSettings — Default values")
struct AppSettingsDefaultTests {

    @Test("Default AppSettings has expected values")
    func defaults() {
        let settings = AppSettings()
        #expect(settings.launchAtLogin == false)
        #expect(settings.menuBarIconStyle == .default)
        #expect(settings.defaultNewAppVolume == 1.0)
        #expect(settings.lockInputDevice == true)
        #expect(settings.showDeviceDisconnectAlerts == true)
    }

    @Test("loudnessEqualizationEnabled defaults to false")
    func loudnessEqualizationEnabledDefault() {
        let settings = AppSettings()
        #expect(settings.loudnessEqualizationEnabled == false)
    }

    @Test("loudnessEqualizationEnabled round-trips through JSON as true")
    func loudnessEqualizationEnabledRoundTrip() throws {
        var settings = AppSettings()
        settings.loudnessEqualizationEnabled = true
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(decoded.loudnessEqualizationEnabled == true)
    }

    @Test("Unified loudness toggle updates compensation and equalization together")
    func unifiedLoudnessToggleSetsBothFlags() {
        var settings = AppSettings()

        settings.setUnifiedLoudnessEnabled(true)
        #expect(settings.loudnessCompensationEnabled == true)
        #expect(settings.loudnessEqualizationEnabled == true)

        settings.setUnifiedLoudnessEnabled(false)
        #expect(settings.loudnessCompensationEnabled == false)
        #expect(settings.loudnessEqualizationEnabled == false)
    }

    @Test("loudnessEqualizationEnabled persists via SettingsManager")
    @MainActor
    func loudnessEqualizationEnabledPersistence() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let manager = SettingsManager(directory: tempDir)
        var newSettings = manager.appSettings
        newSettings.loudnessEqualizationEnabled = true
        manager.updateAppSettings(newSettings)
        #expect(manager.appSettings.loudnessEqualizationEnabled == true)
    }

    @Test("volumeHotkeyStep defaults to .normal")
    func volumeHotkeyStepDefault() {
        let settings = AppSettings()
        #expect(settings.volumeHotkeyStep == .normal)
    }

    @Test("volumeHotkeyStep round-trips through JSON")
    func volumeHotkeyStepRoundTrip() throws {
        var settings = AppSettings()
        settings.volumeHotkeyStep = .fine
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(decoded.volumeHotkeyStep == .fine)
    }

    @Test("Missing volumeHotkeyStep key decodes to .normal")
    func volumeHotkeyStepMissingKeyDefault() throws {
        let json = "{}".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppSettings.self, from: json)
        #expect(decoded.volumeHotkeyStep == .normal)
    }

}

// MARK: - Hidden Devices

@Suite("SettingsManager — hidden device UIDs")
@MainActor
struct SettingsManagerHiddenDevicesTests {

    private func makeManager() -> SettingsManager {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return SettingsManager(directory: tempDir)
    }

    @Test("hideOutputDevice / unhideOutputDevice / isOutputDeviceHidden round-trip")
    func outputHideUnhideParity() {
        let m = makeManager()
        let uid = "uid-output-1"

        #expect(m.isOutputDeviceHidden(uid) == false)
        m.hideOutputDevice(uid: uid)
        #expect(m.isOutputDeviceHidden(uid) == true)
        #expect(m.hiddenOutputDeviceUIDs.contains(uid))
        m.unhideOutputDevice(uid: uid)
        #expect(m.isOutputDeviceHidden(uid) == false)
        #expect(m.hiddenOutputDeviceUIDs.contains(uid) == false)
    }

    @Test("toggleOutputDeviceHidden flips based on persisted state")
    func toggleOutputFlipsFromPersisted() {
        let m = makeManager()
        let uid = "uid-output-2"

        m.toggleOutputDeviceHidden(uid: uid)
        #expect(m.isOutputDeviceHidden(uid) == true)
        m.toggleOutputDeviceHidden(uid: uid)
        #expect(m.isOutputDeviceHidden(uid) == false)
    }

    @Test("legacy hidden input device state is ignored")
    func legacyHiddenInputStateIsIgnored() throws {
        let json = #"{"hiddenInputDeviceUIDs":["legacy-hidden-input"]}"#
        let decoded = try JSONDecoder().decode(SettingsManager.Settings.self, from: Data(json.utf8))
        let reencoded = try JSONEncoder().encode(decoded)
        let object = try #require(JSONSerialization.jsonObject(with: reencoded) as? [String: Any])

        #expect(object["hiddenInputDeviceUIDs"] == nil)
    }
}

// MARK: - Device Icon Override API

@Suite("SettingsManager — deviceIconOverrides API")
@MainActor
struct DeviceIconOverrideTests {
    private func makeManager() -> SettingsManager {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return SettingsManager(directory: tempDir)
    }

    @Test("get/set round-trip for a single UID")
    func setAndGet() {
        let manager = makeManager()
        #expect(manager.getDeviceIconOverride(for: "uid-a") == nil)

        manager.setDeviceIconOverride(for: "uid-a", to: "airpodsmax")
        #expect(manager.getDeviceIconOverride(for: "uid-a") == "airpodsmax")

        manager.setDeviceIconOverride(for: "uid-a", to: "gamecontroller.fill")
        #expect(manager.getDeviceIconOverride(for: "uid-a") == "gamecontroller.fill")
    }

    @Test("Passing nil clears the override")
    func clearOverride() {
        let manager = makeManager()
        manager.setDeviceIconOverride(for: "uid-a", to: "airpodsmax")
        #expect(manager.getDeviceIconOverride(for: "uid-a") == "airpodsmax")

        manager.setDeviceIconOverride(for: "uid-a", to: nil)
        #expect(manager.getDeviceIconOverride(for: "uid-a") == nil)
    }

    @Test("Overrides for different UIDs are independent")
    func independentPerUID() {
        let manager = makeManager()
        manager.setDeviceIconOverride(for: "uid-a", to: "airpodsmax")
        manager.setDeviceIconOverride(for: "uid-b", to: "gamecontroller.fill")

        #expect(manager.getDeviceIconOverride(for: "uid-a") == "airpodsmax")
        #expect(manager.getDeviceIconOverride(for: "uid-b") == "gamecontroller.fill")
        #expect(manager.deviceIconOverrides == ["uid-a": "airpodsmax", "uid-b": "gamecontroller.fill"])
    }

    @Test("resetAllSettings clears all overrides")
    func resetClearsOverrides() {
        let manager = makeManager()
        manager.setDeviceIconOverride(for: "uid-a", to: "airpodsmax")
        manager.setDeviceIconOverride(for: "uid-b", to: "gamecontroller.fill")

        manager.resetAllSettings()

        #expect(manager.getDeviceIconOverride(for: "uid-a") == nil)
        #expect(manager.getDeviceIconOverride(for: "uid-b") == nil)
        #expect(manager.deviceIconOverrides.isEmpty)
    }
}

// MARK: - MenuBarIconStyle

@Suite("MenuBarIconStyle — Enumeration")
struct MenuBarIconStyleTests {

    @Test("allCases has 5 styles")
    func allCasesCount() {
        #expect(MenuBarIconStyle.allCases.count == 5)
    }

    @Test("Only 'default' is not a system symbol")
    func defaultNotSystemSymbol() {
        #expect(!MenuBarIconStyle.default.isSystemSymbol)
        #expect(MenuBarIconStyle.speaker.isSystemSymbol)
        #expect(MenuBarIconStyle.device.isSystemSymbol)
        #expect(MenuBarIconStyle.waveform.isSystemSymbol)
        #expect(MenuBarIconStyle.equalizer.isSystemSymbol)
    }

    @Test("Every style has a non-empty icon name")
    func allHaveIconNames() {
        for style in MenuBarIconStyle.allCases {
            #expect(!style.iconName.isEmpty, "Style \(style.rawValue) has empty icon name")
        }
    }

    @Test("Round-trip through JSON Codable")
    func codableRoundTrip() throws {
        for style in MenuBarIconStyle.allCases {
            let data = try JSONEncoder().encode(style)
            let decoded = try JSONDecoder().decode(MenuBarIconStyle.self, from: data)
            #expect(decoded == style)
        }
    }
}
