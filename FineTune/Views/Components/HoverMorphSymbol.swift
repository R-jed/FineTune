import SwiftUI

/// Ports Amicro's hover morph: outgoing symbol shrinks to 0.5 while fading,
/// incoming symbol grows from 0.5 while fading in.
struct HoverMorphSymbol: View {
    let primarySymbol: String
    let secondarySymbol: String
    let isHovered: Bool
    let primaryColor: Color
    let secondaryColor: Color
    var font: Font = .system(size: 14)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Image(systemName: primarySymbol)
                .foregroundStyle(primaryColor)
                .opacity(isHovered ? 0 : 1)
                .scaleEffect(reduceMotion ? 1 : (isHovered ? 0.5 : 1))

            Image(systemName: secondarySymbol)
                .foregroundStyle(secondaryColor)
                .opacity(isHovered ? 1 : 0)
                .scaleEffect(reduceMotion ? 1 : (isHovered ? 1 : 0.5))
        }
        .font(font)
        .symbolRenderingMode(.hierarchical)
        .animation(
            reduceMotion ? nil : .interpolatingSpring(stiffness: 600, damping: 25),
            value: isHovered
        )
    }
}
