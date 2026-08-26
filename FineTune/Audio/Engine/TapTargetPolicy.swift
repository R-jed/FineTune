// FineTune/Audio/Engine/TapTargetPolicy.swift
import AudioToolbox
import Foundation

/// Decides when FineTune can arm a process tap before Core Audio exposes
/// concrete process object IDs. Bundle-targeted taps require macOS 26+;
/// older supported systems use AudioProcessMonitor's fast process-object path.
enum TapTargetPolicy {
    static func canBundlePrearm(_ app: AudioApp) -> Bool {
        guard #available(macOS 26.0, *) else { return false }
        return app.processObjectIDs.isEmpty
            && !app.isHelperBacked
            && !(app.bundleID?.isEmpty ?? true)
    }

    static func bundlePrearmDescription(for app: AudioApp) -> CATapDescription? {
        guard #available(macOS 26.0, *), canBundlePrearm(app), let bundleID = app.bundleID else {
            return nil
        }

        let description = CATapDescription()
        description.bundleIDs = [bundleID]
        description.processes = []
        description.isExclusive = false
        description.isMixdown = true
        description.isMono = false
        description.muteBehavior = .mutedWhenTapped
        description.isPrivate = true
        description.isProcessRestoreEnabled = true
        description.uuid = UUID()
        return description
    }

    /// Returns true when an existing tap still covers the updated process target.
    /// Bundle-prearmed taps follow the same direct app by bundle identity on macOS 26+.
    /// Concrete taps survive HAL process-list shrinkage, including a transient empty list;
    /// any newly introduced process object still requires a rebuild so it is captured.
    static func shouldKeepBundlePrearm(existingApp: AudioApp, updatedApp: AudioApp) -> Bool {
        guard existingApp.persistenceIdentifier == updatedApp.persistenceIdentifier,
              existingApp.isHelperBacked == updatedApp.isHelperBacked else {
            return false
        }

        if canBundlePrearm(existingApp) {
            return true
        }

        let existingIDs = Set(existingApp.processObjectIDs)
        guard !existingIDs.isEmpty else { return false }
        return Set(updatedApp.processObjectIDs).isSubset(of: existingIDs)
    }
}
