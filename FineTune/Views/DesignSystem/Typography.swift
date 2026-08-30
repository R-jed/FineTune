import SwiftUI

extension DesignTokens {
    // MARK: - Typography

    enum Typography {
        /// Page title used by Settings content workspaces.
        static let pageTitle = Font.system(size: 20, weight: .semibold)

        /// Shared section-title grammar across Settings and the popup.
        static let sectionHeader = Font.system(size: 12, weight: .semibold)
        static let sectionHeaderTracking: CGFloat = 0.2

        /// App/device name in rows
        static let rowName = Font.system(size: 13, weight: .regular)

        /// Bold variant for default device name
        static let rowNameBold = Font.system(size: 13, weight: .semibold)

        /// Volume percentage display
        static let percentage = Font.system(size: 11, weight: .medium, design: .monospaced)

        /// Small caption text
        static let caption = Font.system(size: 10, weight: .regular)

        /// Device picker text
        static let pickerText = Font.system(size: 11, weight: .regular)

        /// EQ frequency labels
        static let eqLabel = Font.system(size: 10, weight: .medium, design: .monospaced)

        /// AutoEQ card profile name
        static let cardProfileName = Font.system(size: 12, weight: .semibold)

        /// AutoEQ card source/measuredBy
        static let cardSource = Font.system(size: 10, weight: .regular)

        /// Settings card header (sentence case, 13pt semibold)
        static let cardHeader = Font.system(size: 13, weight: .semibold)

        /// Settings row description (11pt regular, tertiary)
        static let rowDescription = Font.system(size: 11, weight: .regular)
    }

}
