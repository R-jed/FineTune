// FineTune/Audio/Engine/AppListCoordinator.swift
import Foundation

/// Owns the app-list surface that is pure `SettingsManager` persistence: global order,
/// pin membership/metadata, the persistence half of ignoring, and identifier-addressed
/// app settings. Live tap/engine state stays in `AudioEngine`.
@MainActor
final class AppListCoordinator {
    private let settingsManager: SettingsManager

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }

    // MARK: - App order

    func registerVisibleApps(_ apps: [AudioApp]) {
        let visibleByIdentifier = Dictionary(
            apps
                .filter { !settingsManager.isIgnored($0.persistenceIdentifier) }
                .map { ($0.persistenceIdentifier, $0) },
            uniquingKeysWith: { $0.merging($1) }
        )
        let identifiers = visibleByIdentifier.values
            .sorted { lhs, rhs in
                let nameOrder = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
                return lhs.persistenceIdentifier.localizedCaseInsensitiveCompare(rhs.persistenceIdentifier) == .orderedAscending
            }
            .map(\.persistenceIdentifier)
        settingsManager.ensureAppsInOrder(identifiers)
    }

    func moveApp(_ identifier: String, to targetIdentifier: String, currentOrder: [String]) {
        settingsManager.moveApp(identifier, to: targetIdentifier, currentOrder: currentOrder)
    }

    // MARK: - Pinning / placement

    func pinApp(_ app: AudioApp) {
        settingsManager.pinApp(
            app.persistenceIdentifier,
            info: PinnedAppInfo(
                persistenceIdentifier: app.persistenceIdentifier,
                displayName: app.name,
                bundleID: app.bundleID
            )
        )
    }

    func pinApp(_ info: PinnedAppInfo) {
        settingsManager.pinApp(info.persistenceIdentifier, info: info)
    }

    func unpinApp(_ identifier: String) {
        settingsManager.unpinApp(identifier)
    }

    func isPinned(identifier: String) -> Bool {
        settingsManager.isPinned(identifier)
    }

    func pinnedAppInfo() -> [PinnedAppInfo] {
        settingsManager.getPinnedAppInfo()
    }

    func pinnedAppInfo(identifier: String) -> PinnedAppInfo? {
        settingsManager.pinnedAppInfo(for: identifier)
    }

    @discardableResult
    func placeApp(
        _ identifier: String,
        visibleOrder: [String],
        pinned: Bool,
        info: PinnedAppInfo?
    ) -> Bool {
        settingsManager.placeApp(
            identifier,
            visibleOrder: visibleOrder,
            pinned: pinned,
            info: info
        )
    }

    func addSelectedPinnedApp(_ info: PinnedAppInfo, visibleOrder: [String]) {
        settingsManager.addSelectedPinnedApp(info, visibleOrder: visibleOrder)
    }

    // MARK: - Ignored Apps (persistence half; tap teardown stays in AudioEngine)

    func recordIgnore(_ app: AudioApp) {
        let info = IgnoredAppInfo(
            persistenceIdentifier: app.persistenceIdentifier,
            displayName: app.name,
            bundleID: app.bundleID
        )
        settingsManager.ignoreApp(app.persistenceIdentifier, info: info)
    }

    func recordIgnore(_ info: PinnedAppInfo) {
        settingsManager.ignoreApp(
            info.persistenceIdentifier,
            info: IgnoredAppInfo(
                persistenceIdentifier: info.persistenceIdentifier,
                displayName: info.displayName,
                bundleID: info.bundleID
            )
        )
    }

    func clearIgnore(_ identifier: String) {
        settingsManager.unignoreApp(identifier)
    }

    func isIgnored(identifier: String) -> Bool {
        settingsManager.isIgnored(identifier)
    }

    // MARK: - Inactive App Settings (by persistence identifier)

    func getVolumeForInactive(identifier: String) -> Float {
        settingsManager.getVolume(for: identifier) ?? 1.0
    }

    func setVolumeForInactive(identifier: String, to volume: Float) {
        settingsManager.setVolume(for: identifier, to: volume)
    }

    func getBoostForInactive(identifier: String) -> BoostLevel {
        settingsManager.getBoost(for: identifier) ?? .x1
    }

    func setBoostForInactive(identifier: String, to boost: BoostLevel) {
        settingsManager.setBoost(for: identifier, to: boost)
    }

    func getMuteForInactive(identifier: String) -> Bool {
        settingsManager.getMute(for: identifier) ?? false
    }

    func setMuteForInactive(identifier: String, to muted: Bool) {
        settingsManager.setMute(for: identifier, to: muted)
    }

    func getEQSettingsForInactive(identifier: String) -> EQSettings {
        settingsManager.getEQSettings(for: identifier)
    }

    func setEQSettingsForInactive(_ settings: EQSettings, identifier: String) {
        settingsManager.setEQSettings(settings, for: identifier)
    }

    func getDeviceRoutingForInactive(identifier: String) -> String? {
        settingsManager.getDeviceRouting(for: identifier)
    }

    func setDeviceRoutingForInactive(identifier: String, deviceUID: String?) {
        if let deviceUID = deviceUID {
            settingsManager.setDeviceRouting(for: identifier, deviceUID: deviceUID)
        } else {
            settingsManager.setFollowDefault(for: identifier)
        }
    }

    func isFollowingDefaultForInactive(identifier: String) -> Bool {
        settingsManager.isFollowingDefault(for: identifier)
    }

    func getDeviceSelectionModeForInactive(identifier: String) -> DeviceSelectionMode {
        settingsManager.getDeviceSelectionMode(for: identifier) ?? .single
    }

    func setDeviceSelectionModeForInactive(identifier: String, to mode: DeviceSelectionMode) {
        settingsManager.setDeviceSelectionMode(for: identifier, to: mode)
    }

    func getSelectedDeviceUIDsForInactive(identifier: String) -> Set<String> {
        settingsManager.getSelectedDeviceUIDs(for: identifier) ?? []
    }

    func setSelectedDeviceUIDsForInactive(identifier: String, to uids: Set<String>) {
        settingsManager.setSelectedDeviceUIDs(for: identifier, to: uids)
    }
}
