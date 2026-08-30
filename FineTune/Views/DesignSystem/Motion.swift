import Foundation
import SwiftUI

extension DesignTokens {
    /// Motion roles describe intent rather than individual component timing.
    /// Values intentionally match the pre-foundation implementation so this
    /// refactor changes ownership, not animation behavior.
    enum Animation {
        /// Brief icon/hover/pressed feedback.
        static let micro = SwiftUI.Animation.easeOut(duration: 0.12)

        /// Selection and small control-state changes.
        static let selection = SwiftUI.Animation.easeOut(duration: 0.15)

        /// Structural insertion/removal such as inline inspectors.
        static let structural = SwiftUI.Animation.easeOut(duration: 0.18)

        /// Continuous row-crossing and settle motion while reordering.
        static let reorder = SwiftUI.Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.30)

        /// Existing spring retained for components whose behavior already uses it.
        static let quick = SwiftUI.Animation.spring(response: 0.2, dampingFraction: 0.85)

        /// Compatibility alias for existing hover call sites during migration.
        static let hover = micro

        /// Source meter bar transition.
        static let vuMeterLevel = SwiftUI.Animation.linear(duration: 0.05)
    }

    enum Timing {
        /// Source meter UI update interval (30fps).
        static let vuMeterUpdateInterval: TimeInterval = 1.0 / 30.0
    }
}
