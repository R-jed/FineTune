import Foundation

/// The audio direction currently presented by the menu-bar popup.
enum PopupAudioDirection: Hashable {
    case output
    case input

    init(showInput: Bool) {
        self = showInput ? .input : .output
    }

    var isInput: Bool { self == .input }
}

/// Stable page identity for the popup. Direction and page depth live in one
/// value so Output/Input changes cannot drift out of sync with management mode.
enum PopupPage: Hashable {
    case main(PopupAudioDirection)
    case management(PopupAudioDirection)

    var direction: PopupAudioDirection {
        switch self {
        case .main(let direction), .management(let direction):
            return direction
        }
    }

    var isManagement: Bool {
        if case .management = self { return true }
        return false
    }

    func enteringManagement() -> PopupPage {
        .management(direction)
    }

    func selecting(_ requestedDirection: PopupAudioDirection) -> PopupPageSelectionTransition? {
        guard requestedDirection != direction else { return nil }

        switch self {
        case .main:
            return PopupPageSelectionTransition(
                page: .main(requestedDirection),
                managementDirectionToPersist: nil
            )
        case .management(let currentDirection):
            return PopupPageSelectionTransition(
                page: .management(requestedDirection),
                managementDirectionToPersist: currentDirection
            )
        }
    }
}

struct PopupPageSelectionTransition: Equatable {
    let page: PopupPage
    let managementDirectionToPersist: PopupAudioDirection?
}
