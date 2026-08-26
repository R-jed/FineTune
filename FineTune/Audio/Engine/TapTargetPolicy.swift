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

    static func shouldKeepBundlePrearm(existingApp: AudioApp, updatedApp: AudioApp) -> Bool {
        canBundlePrearm(existingApp)
            && existingApp.persistenceIdentifier == updatedApp.persistenceIdentifier
            && !updatedApp.isHelperBacked
    }
}
