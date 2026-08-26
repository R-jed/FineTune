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

    /// Returns true when an existing tap should survive a process-object list change.
    /// Bundle-prearmed taps already follow the app by bundle identity on macOS 26+.
    /// Concrete process taps are also kept when HAL temporarily reports no process object;
    /// a later non-empty replacement object set still forces a rebuild.
    static func shouldKeepBundlePrearm(existingApp: AudioApp, updatedApp: AudioApp) -> Bool {
        guard existingApp.persistenceIdentifier == updatedApp.persistenceIdentifier,
              existingApp.isHelperBacked == updatedApp.isHelperBacked else {
            return false
        }

        if canBundlePrearm(existingApp) {
            return true
        }

        return !existingApp.processObjectIDs.isEmpty && updatedApp.processObjectIDs.isEmpty
    }
}
