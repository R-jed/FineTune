import SwiftUI

/// Hover emphasis that preserves the control's current semantic symbol.
/// The secondary symbol remains part of the call-site contract until callers are simplified,
/// but hover itself only changes emphasis and never previews the opposite action.
struct HoverMorphSymbol: View {
    let primarySymbol: String
    let secondarySymbol: String
    let isHovered: Bool
    let primaryColor: Color
    let secondaryColor: Color
    var font: Font = .system(size: 14)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: primarySymbol)
            .font(font)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isHovered ? secondaryColor : primaryColor)
            .animation(
                reduceMotion ? nil : DesignTokens.Animation.hover,
                value: isHovered
            )
    }
}
