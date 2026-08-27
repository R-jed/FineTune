// FineTune/Views/Components/MuteButton.swift
import SwiftUI

/// High-frequency mute control. The glyph always communicates current state;
/// hover only changes emphasis so it never previews the opposite semantic state.
struct MuteButton: View {
    let isMuted: Bool
    let levelFraction: Double
    let action: () -> Void

    init(isMuted: Bool, levelFraction: Double = 1.0, action: @escaping () -> Void) {
        self.isMuted = isMuted
        self.levelFraction = levelFraction
        self.action = action
    }

    var body: some View {
        BaseMuteButton(
            isMuted: isMuted,
            mutedIcon: "speaker.slash.fill",
            unmutedIcon: VolumeBucket.bucket(for: Float(levelFraction)).symbolName,
            layoutReferenceIcon: "speaker.wave.3.fill",
            mutedHelp: "Unmute",
            unmutedHelp: "Mute",
            action: action
        )
    }
}

/// A mute button for input devices (microphones).
struct InputMuteButton: View {
    let isMuted: Bool
    let action: () -> Void

    var body: some View {
        BaseMuteButton(
            isMuted: isMuted,
            mutedIcon: "mic.slash.fill",
            unmutedIcon: "mic.fill",
            layoutReferenceIcon: nil,
            mutedHelp: "Unmute microphone",
            unmutedHelp: "Mute microphone",
            action: action
        )
    }
}

// MARK: - Base Implementation

private struct BaseMuteButton: View {
    let isMuted: Bool
    let mutedIcon: String
    let unmutedIcon: String
    let layoutReferenceIcon: String?
    let mutedHelp: LocalizedStringResource
    let unmutedHelp: LocalizedStringResource
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                if let layoutReferenceIcon {
                    Image(systemName: layoutReferenceIcon)
                        .opacity(0)
                }

                Image(systemName: isMuted ? mutedIcon : unmutedIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(symbolColor)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isMuted)
            }
            .frame(
                minWidth: DesignTokens.Dimensions.minTouchTarget,
                minHeight: DesignTokens.Dimensions.minTouchTarget
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(MuteButtonPressStyle())
        .onHover { isHovered = $0 }
        .help(isMuted ? mutedHelp : unmutedHelp)
    }

    private var symbolColor: Color {
        if isMuted {
            return DesignTokens.Colors.mutedIndicator
        }
        return isHovered
            ? DesignTokens.Colors.interactiveHover
            : DesignTokens.Colors.interactiveDefault
    }
}

private struct MuteButtonPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.97 : 1.0)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.08),
                value: configuration.isPressed
            )
    }
}

// MARK: - Previews

#Preview("Mute Button States") {
    ComponentPreviewContainer {
        HStack(spacing: DesignTokens.Spacing.lg) {
            VStack {
                MuteButton(isMuted: false) {}
                Text("Unmuted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack {
                MuteButton(isMuted: true) {}
                Text("Muted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Input Mute Button States") {
    ComponentPreviewContainer {
        HStack(spacing: DesignTokens.Spacing.lg) {
            VStack {
                InputMuteButton(isMuted: false) {}
                Text("Unmuted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack {
                InputMuteButton(isMuted: true) {}
                Text("Muted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Mute Button Interactive") {
    struct InteractivePreview: View {
        @State private var isMuted = false

        var body: some View {
            ComponentPreviewContainer {
                VStack(spacing: DesignTokens.Spacing.md) {
                    MuteButton(isMuted: isMuted) {
                        isMuted.toggle()
                    }

                    Text(isMuted ? "Muted" : "Playing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    return InteractivePreview()
}
