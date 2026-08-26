// FineTune/Audio/Engine/TapTargetPolicy.swift
import AudioToolbox
import Foundation

/// Decides whether an existing process tap still covers the same logical app.
/// macOS 26+ can use bundle-targeted taps, which are stable across HAL process-object churn.
/// Older supported systems keep using concrete process-object targeting.
enum TapTargetPolicy {
    static func canBundlePrearm(_ app: AudioApp) -> Bool {
        guard #available(macOS 26.0, *) else { return false }
        guard !app.tapBundleIDs.isEmpty else { return false }

        // Once concrete process objects exist, require the producer identity reported by
        // Core Audio. Quiet direct apps can still prearm from the presentation bundle ID.
        guard app.processObjectIDs.isEmpty || !app.producerBundleIDs.isEmpty else {
            return false
        }

        // A helper-backed app with no Core Audio producer identity cannot be safely
        // bundle-targeted because the presentation app bundle may not produce the audio.
        if app.isHelperBacked && app.producerBundleIDs.isEmpty {
            return false
        }

        return true
    }

    static func bundlePrearmDescription(for app: AudioApp) -> CATapDescription? {
        guard #available(macOS 26.0, *), canBundlePrearm(app) else {
            return nil
        }

        let description = CATapDescription()
        description.bundleIDs = app.tapBundleIDs
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

    /// Returns true when the existing tap target still covers the updated app.
    /// Bundle targets ignore transient process-object changes and rebuild only when
    /// a newly learned producer bundle falls outside the current target set.
    /// Concrete targets survive process-list shrinkage, including a transient empty list.
    static func shouldKeepBundlePrearm(existingApp: AudioApp, updatedApp: AudioApp) -> Bool {
        guard existingApp.persistenceIdentifier == updatedApp.persistenceIdentifier else {
            return false
        }

        if canBundlePrearm(existingApp) {
            if updatedApp.isHelperBacked && updatedApp.producerBundleIDs.isEmpty {
                return false
            }
            return Set(updatedApp.tapBundleIDs).isSubset(of: Set(existingApp.tapBundleIDs))
        }

        let existingIDs = Set(existingApp.processObjectIDs)
        guard !existingIDs.isEmpty else { return false }
        return Set(updatedApp.processObjectIDs).isSubset(of: existingIDs)
    }
}
