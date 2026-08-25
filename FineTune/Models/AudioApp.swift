// FineTune/Models/AudioApp.swift
import AppKit
import AudioToolbox

struct AudioApp: Identifiable, Hashable {
    let id: pid_t
    let processObjectIDs: [AudioObjectID]
    let name: String
    let icon: NSImage
    let bundleID: String?
    let isHelperBacked: Bool
    let isAudioActive: Bool

    init(
        id: pid_t,
        processObjectIDs: [AudioObjectID],
        name: String,
        icon: NSImage,
        bundleID: String?,
        isHelperBacked: Bool = false,
        isAudioActive: Bool = true
    ) {
        self.id = id
        self.processObjectIDs = processObjectIDs
        self.name = name
        self.icon = icon
        self.bundleID = bundleID
        self.isHelperBacked = isHelperBacked
        self.isAudioActive = isAudioActive
    }

    var persistenceIdentifier: String {
        bundleID ?? "name:\(name)"
    }

    func merging(_ other: AudioApp) -> AudioApp {
        let primary = id <= other.id ? self : other
        return AudioApp(
            id: primary.id,
            processObjectIDs: Array(Set(processObjectIDs).union(other.processObjectIDs)).sorted(),
            name: primary.name,
            icon: primary.icon,
            bundleID: primary.bundleID,
            isHelperBacked: isHelperBacked || other.isHelperBacked,
            isAudioActive: isAudioActive || other.isAudioActive
        )
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(persistenceIdentifier)
        hasher.combine(processObjectIDs)
        hasher.combine(isHelperBacked)
        hasher.combine(isAudioActive)
    }

    static func == (lhs: AudioApp, rhs: AudioApp) -> Bool {
        lhs.id == rhs.id
            && lhs.persistenceIdentifier == rhs.persistenceIdentifier
            && lhs.processObjectIDs == rhs.processObjectIDs
            && lhs.isHelperBacked == rhs.isHelperBacked
            && lhs.isAudioActive == rhs.isAudioActive
    }
}
