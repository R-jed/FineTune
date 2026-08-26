// FineTune/Audio/Engine/TapTargetPolicy.swift
import AudioToolbox
import Foundation

/// Decides when FineTune can arm a process tap before Core Audio exposes
/// concrete process object IDs. Pre-arming is intentionally limited to a
/// direct app bundle with explicit routing intent; ordinary follow-default
/// apps keep the existing lazy process-object path.
enum TapTargetPolicy {
    static func canBundlePrearm(_ app: AudioApp) -> Bool {
        app.processObjectIDs.isEmpty
            && app.bundleID != nil
            && !app.isHelperBacked
    }

    static func bundlePrearmDescription(for app: AudioApp) -> CATapDescription? {
        guard canBundlePrearm(app), let bundleID = app.bundleID else { return nil }

        let description = CATapDescription()
        description.uuid = UUID()
        description.processes = []
        description.bundleIDs = [bundleID]
        description.isExclusive = false
        description.isMixdown = true
        description.isMono = false
        description.isPrivate = true
        description.muteBehavior = .mutedWhenTapped
        description.isProcessRestoreEnabled = true
        return description
    }

    /// A bundle-prearmed direct-app tap follows the same bundle across Core Audio
    /// process-object churn. Helper-backed audio is deliberately rebuilt through
    /// the existing responsibility-resolution path because the helper may use a
    /// different bundle ID from the parent application.
    static func shouldKeepBundlePrearm(existingApp: AudioApp, updatedApp: AudioApp) -> Bool {
        canBundlePrearm(existingApp)
            && existingApp.persistenceIdentifier == updatedApp.persistenceIdentifier
            && !updatedApp.isHelperBacked
    }
}
