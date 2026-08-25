// FineTune/Views/Components/VUMeter.swift
import SwiftUI

/// dBFS thresholds for the source meter's visible 60 dB range.
/// This list is the single source of truth for both bar count and thresholds.
private let sourceMeterDBThresholds: [Float] = [-60, -42, -30, -20, -14, -8, -3, 0]

/// Vertical source-activity meter for a captured app audio signal.
/// The audio layer owns peak timing and release; this view only maps level to bars.
struct VUMeter: View {
    let level: Float
    var isMuted: Bool = false

    var body: some View {
        VStack(spacing: 1) {
            ForEach(sourceMeterDBThresholds.indices.reversed(), id: \.self) { index in
                VUMeterBar(
                    thresholdDB: sourceMeterDBThresholds[index],
                    level: level,
                    isMuted: isMuted
                )
            }
        }
        .frame(width: 10, height: DesignTokens.Dimensions.rowContentHeight - 4)
    }
}

/// Individual bar in the source-activity meter.
private struct VUMeterBar: View {
    let thresholdDB: Float
    let level: Float
    var isMuted: Bool = false

    /// Threshold for this bar in linear amplitude: 10^(dB/20).
    private var threshold: Float {
        powf(10, thresholdDB / 20)
    }

    private var isLit: Bool {
        level >= threshold
    }

    /// Color bands follow the dB thresholds, so changing segment count cannot
    /// silently change which segment is treated as high or full-scale activity.
    private var barColor: Color {
        if isMuted {
            return DesignTokens.Colors.vuMuted
        }
        if thresholdDB < -14 {
            return DesignTokens.Colors.vuGreen
        } else if thresholdDB < -3 {
            return DesignTokens.Colors.vuYellow
        } else if thresholdDB < 0 {
            return DesignTokens.Colors.vuOrange
        } else {
            return DesignTokens.Colors.vuRed
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 0.5)
            .fill(isLit ? barColor : DesignTokens.Colors.vuUnlit)
            .animation(DesignTokens.Animation.vuMeterLevel, value: isLit)
    }
}

// MARK: - Previews

#Preview("VU Meter - Vertical") {
    ComponentPreviewContainer {
        VStack(spacing: DesignTokens.Spacing.md) {
            HStack {
                Text("0%")
                    .font(.caption)
                VUMeter(level: 0)
            }

            HStack {
                Text("25%")
                    .font(.caption)
                VUMeter(level: 0.25)
            }

            HStack {
                Text("50%")
                    .font(.caption)
                VUMeter(level: 0.5)
            }

            HStack {
                Text("75%")
                    .font(.caption)
                VUMeter(level: 0.75)
            }

            HStack {
                Text("100%")
                    .font(.caption)
                VUMeter(level: 1.0)
            }
        }
    }
}

#Preview("VU Meter - Animated") {
    struct AnimatedPreview: View {
        @State private var level: Float = 0

        var body: some View {
            ComponentPreviewContainer {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    VUMeter(level: level)

                    Slider(value: Binding(
                        get: { Double(level) },
                        set: { level = Float($0) }
                    ))
                }
            }
        }
    }
    return AnimatedPreview()
}
