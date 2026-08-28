// FineTune/Views/Components/LiquidGlassSlider.swift
import SwiftUI

/// A slider using native SwiftUI Slider for Liquid Glass effect on macOS 26+
/// Styled to match the minimal track appearance of device sliders
struct LiquidGlassSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let showUnityMarker: Bool
    let onEditingChanged: ((Bool) -> Void)?
    let accessibilityLabel: Text

    @State private var isEditing = false
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    /// Keep the native thumb/focus treatment visible for every active input path.
    private var showThumb: Bool {
        isHovered || isEditing || isFocused
    }

    init(
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0...1,
        showUnityMarker: Bool = false,
        onEditingChanged: ((Bool) -> Void)? = nil,
        accessibilityLabel: Text = Text("Volume")
    ) {
        self._value = value
        self.range = range
        self.showUnityMarker = showUnityMarker
        self.onEditingChanged = onEditingChanged
        self.accessibilityLabel = accessibilityLabel
    }

    private let trackHeight: CGFloat = 4

    private var normalizedValue: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(1, max(0, (value - range.lowerBound) / span))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Custom track overlay (always visible, hides native track)
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(DesignTokens.Colors.sliderTrack)
                        .frame(height: trackHeight)

                    // A true zero value has no accent-colored fill.
                    if normalizedValue > 0 {
                        Capsule()
                            .fill(DesignTokens.Colors.accentPrimary)
                            .frame(width: geo.size.width * normalizedValue, height: trackHeight)
                    }
                }
                .frame(maxHeight: .infinity)
                .allowsHitTesting(false)

                // Unity marker at 50% (horizontally centered, vertically centered via frame)
                if showUnityMarker {
                    HStack {
                        Spacer()
                        Rectangle()
                            .fill(DesignTokens.Colors.unityMarker)
                            .frame(width: 1.5, height: 8)
                        Spacer()
                    }
                    .frame(maxHeight: .infinity)
                    .allowsHitTesting(false)
                }

                // Native SwiftUI Slider - gets Liquid Glass thumb on macOS 26+
                // Resting chrome stays quiet; hover, drag, and keyboard focus reveal it.
                Slider(value: $value, in: range) { editing in
                    isEditing = editing
                    onEditingChanged?(editing)
                }
                .controlSize(.mini)
                .tint(.clear)  // Hide native track, we draw our own
                .focused($isFocused)
                .accessibilityLabel(accessibilityLabel)
                .opacity(showThumb ? 1 : 0.01)
            }
        }
        .frame(minHeight: DesignTokens.Dimensions.minTouchTarget)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview

#Preview("Liquid Glass Slider") {
    struct PreviewWrapper: View {
        @State private var value: Double = 0.5

        var body: some View {
            VStack(spacing: 30) {
                LiquidGlassSlider(value: $value, showUnityMarker: true)
                    .frame(width: 200)

                Text("\(Int(value * 200))%")
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .background(Color.black)
        }
    }
    return PreviewWrapper()
}
