import AppKit
import os

@MainActor
protocol MenuBarPopupControlling: AnyObject {
    func toggle()
}

/// Direct bridge from global shortcuts to the FineTune-owned menu-bar host.
/// The Scene attaches the live status-item toggle after it creates the host.
@MainActor
final class MenuBarPopupController: MenuBarPopupControlling {
    private static let logger = Logger(
        subsystem: "com.finetuneapp.FineTune",
        category: "MenuBarPopupController"
    )

    private var toggleHandler: (() -> Void)?

    func attach(toggle: @escaping () -> Void) {
        toggleHandler = toggle
    }

    func detach() {
        toggleHandler = nil
    }

    func toggle() {
        guard let toggleHandler else {
            Self.logger.debug("toggle: menu-bar host not attached yet; ignoring")
            return
        }
        toggleHandler()
    }
}
