// FineTune/Models/DisplayableApp.swift
import AppKit
import UniformTypeIdentifiers

/// Stable presentation identity for either a running app or a pinned app whose
/// process is currently unavailable. Identity remains the persistence identifier
/// so relaunches replace the inactive row without changing its ordering slot.
enum DisplayableApp: Identifiable {
    case active(AudioApp)
    case pinnedInactive(PinnedAppInfo)

    var id: String {
        switch self {
        case .active(let app): app.persistenceIdentifier
        case .pinnedInactive(let info): info.persistenceIdentifier
        }
    }

    var displayName: String {
        switch self {
        case .active(let app): app.name
        case .pinnedInactive(let info): info.displayName
        }
    }

    var icon: NSImage {
        switch self {
        case .active(let app): app.icon
        case .pinnedInactive(let info): Self.loadIcon(bundleID: info.bundleID)
        }
    }

    var app: AudioApp? {
        guard case .active(let app) = self else { return nil }
        return app
    }

    var pinInfo: PinnedAppInfo {
        switch self {
        case .active(let app):
            PinnedAppInfo(
                persistenceIdentifier: app.persistenceIdentifier,
                displayName: app.name,
                bundleID: app.bundleID
            )
        case .pinnedInactive(let info):
            info
        }
    }

    /// Loads a persisted app icon for management surfaces such as Hidden Apps.
    static func loadIcon(bundleID: String?) -> NSImage {
        if let bundleID,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }
}
