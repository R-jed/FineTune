// FineTune/Shortcuts/ShortcutAction.swift
import Foundation

/// Every user-configurable keyboard shortcut in FineTune.
///
/// The raw value is the **persistence key** stored in `settings.json` and must
/// remain stable across releases. The three `targetApp*` values deliberately
/// keep their historical `frontmostApp*` strings for backward compatibility.
nonisolated enum ShortcutAction: String, CaseIterable, Codable, Sendable {
    case togglePopup
    case targetAppVolumeUp = "frontmostAppVolumeUp"
    case targetAppVolumeDown = "frontmostAppVolumeDown"
    case targetAppMuteToggle = "frontmostAppMuteToggle"

    var displayName: LocalizedStringResource {
        switch self {
        case .togglePopup:
            "Toggle FineTune Popup"
        case .targetAppVolumeUp:
            "App Volume Up"
        case .targetAppVolumeDown:
            "App Volume Down"
        case .targetAppMuteToggle:
            "App Mute"
        }
    }
}
