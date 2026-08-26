// FineTune/Views/Components/MuteButton.swift
import SwiftUI

/// A mute button with an Amicro-style hover morph. Unmuted wave bucket mirrors
/// TahoeStyleHUD.waveIconName so the popup, menu-bar icon, and on-screen HUD agree.
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

/// A mute button for input devices (microphones)
/// Shows mic when unmuted, mic.slash when muted
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

/// Shared mute button implementation with configurable icons
private struct BaseMuteButton: View {
    let isMuted: Bool
    let mutedIcon: String
    let unmutedIcon: String
    let layoutReferenceIcon: String?
    let mutedHelp: LocalizedStringResource
    let unmutedHelp: LocalizedStringResource
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if let layoutReferenceIcon {
                    // Keeps the button width stable across wave-bucket changes.
                    Image(systemName: layoutReferenceIcon)
                        .opacity(0)
                }

                HoverMorphSymbol(
                    primarySymbol: isMuted ? mutedIcon : unmutedIcon,
                    secondarySymbol: isMuted ? unmutedIcon : mutedIcon,
                    isHovered: isHovered,
                    primaryColor: symbolColor(isMuted: isMuted, hovered: false),
                    secondaryColor: symbolColor(isMuted: !isMuted, hovered: true),
                    font: .system(size: 14)
                )
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

    private func symbolColor(isMuted: Bool, hovered: Bool) -> Color {
        if isMuted {
            return DesignTokens.Colors.mutedIndicator
        }
        return hovered
            ? DesignTokens.Colors.interactiveHover
            : DesignTokens.Colors.interactiveDefault
    }
}


/// Internal button style for press feedback
private struct MuteButtonPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.9 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.6),
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
