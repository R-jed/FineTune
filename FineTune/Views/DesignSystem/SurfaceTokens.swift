import AppKit
import SwiftUI

extension DesignTokens {
    /// Semantic surface roles shared by Settings, menu-bar popup, inspectors,
    /// and transient controls. These aliases intentionally preserve the current
    /// rendered values; later visual-system work changes the role once here
    /// instead of tuning individual components independently.
    enum Surface {
        /// Stable content canvas used by Settings and other non-floating workspaces.
        static let canvas = Color(nsColor: .windowBackgroundColor)
        static let hover = Colors.hoverSurface
        static let recessed = Colors.recessedBackground
        static let raised = Colors.eqCardBackground
        static let emphasized = Colors.glassFillStrong
    }

    /// Semantic edge roles paired with `Surface` elevation states.
    enum Stroke {
        static let resting = Colors.glassRowBorder
        static let hover = Colors.glassRowBorderHover
        static let raised = Colors.eqCardBorder
    }
}


extension DesignTokens {
    enum AppKitSurface {
        /// Popup-level Liquid Glass tuning. Light mode receives a very small
        /// neutral tint to avoid the washed-out white sheet seen on bright
        /// desktops; dark mode remains untinted. This is intentionally applied
        /// once at the root glass surface rather than per-row.
        static let popupGlassTint = NSColor(name: NSColor.Name("FineTunePopupGlassTint")) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.clear
                : NSColor.black.withAlphaComponent(0.045)
        }
    }
}
