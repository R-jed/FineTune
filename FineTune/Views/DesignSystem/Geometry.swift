import SwiftUI

extension DesignTokens {
    // MARK: - Spacing (standard 1× multiplier)

    enum Spacing {
        /// 2pt - Extra extra small
        static let xxs: CGFloat = 2

        /// 4pt - Extra small
        static let xs: CGFloat = 4

        /// 8pt - Small
        static let sm: CGFloat = 8

        /// 12pt - Medium
        static let md: CGFloat = 12

        /// 16pt - Large
        static let lg: CGFloat = 16

        /// 20pt - Extra large
        static let xl: CGFloat = 20

        /// 24pt - Extra extra large
        static let xxl: CGFloat = 24
    }

    // MARK: - Dimensions

    enum Dimensions {
        // MARK: Base Configuration

        /// Main popup width
        static let popupWidth: CGFloat = 510

        /// Content padding
        static var contentPadding: CGFloat { Spacing.lg }

        /// Available content width after padding
        static var contentWidth: CGFloat {
            popupWidth - (contentPadding * 2)
        }

        // MARK: Fixed Dimensions

        /// Max height for scrollable content
        static let maxScrollHeight: CGFloat = 400

        // MARK: Corner Radii (rounded style - 10pt)

        /// Corner radius for popup
        static let cornerRadius: CGFloat = 12

        /// Corner radius for row cards (glass bars)
        static let rowRadius: CGFloat = 10

        /// Corner radius for buttons/pickers
        static let buttonRadius: CGFloat = 6

        /// App/device icon size
        static let iconSize: CGFloat = 22

        /// Small icon size
        static let iconSizeSmall: CGFloat = 14

        // MARK: Slider Dimensions (minimal style)

        /// Slider track height
        static let sliderTrackHeight: CGFloat = 3

        /// Slider thumb width (pill shape)
        static let sliderThumbWidth: CGFloat = 16

        /// Slider thumb height (pill shape)
        static let sliderThumbHeight: CGFloat = 10

        /// Circular thumb size
        static let sliderThumbSize: CGFloat = 12

        /// Minimum touch target
        static let minTouchTarget: CGFloat = 20

        /// Row content height
        static let rowContentHeight: CGFloat = 28

        // MARK: Component Widths

        /// Slider width
        static let sliderWidth: CGFloat = 140

        /// Minimum slider width
        static let sliderMinWidth: CGFloat = 120

        /// Percentage text width (fixed to prevent layout shift)
        static let percentageWidth: CGFloat = 40

        // MARK: Settings Row

        /// Settings row icon column width
        static let settingsIconWidth: CGFloat = 24

        /// Settings slider width
        static let settingsSliderWidth: CGFloat = 200

        /// Settings percentage text width
        static let settingsPercentageWidth: CGFloat = 44

        /// Settings picker width
        static let settingsPickerWidth: CGFloat = 120

    }

}
