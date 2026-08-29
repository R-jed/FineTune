import AppKit
import SwiftUI

/// Stable outer structure for the menu-bar popup. Page-specific content lives
/// inside the content viewport; toolbar and footer retain identity across page
/// switches so later structural animations have a single, stable shell.
struct PopupShell<Content: View>: View {
    let direction: PopupAudioDirection
    let isManaging: Bool
    let width: CGFloat
    let contentPadding: CGFloat
    let onSelectDirection: (PopupAudioDirection) -> Void
    let onToggleManagement: () -> Void
    let onOpenSettings: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var deviceToggleNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            toolbar
                .padding(.bottom, DesignTokens.Spacing.xs)

            content()

            Divider()
                .padding(.top, DesignTokens.Spacing.xs)

            PopupFooter()
        }
        .padding(contentPadding)
        .frame(width: width)
    }

    private var toolbar: some View {
        HStack {
            deviceTabsHeader

            Spacer()

            Button(action: onToggleManagement) {
                Label(
                    managementTitle,
                    systemImage: isManaging ? "checkmark" : "pencil"
                )
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: isManaging ? .bold : .regular))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(DesignTokens.Colors.interactiveDefault)
            .frame(
                minWidth: DesignTokens.Dimensions.minTouchTarget,
                minHeight: DesignTokens.Dimensions.minTouchTarget
            )
            .contentShape(Rectangle())
            .animation(
                reduceMotion ? nil : DesignTokens.Animation.micro,
                value: isManaging
            )
            .help(managementTitle)

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(DesignTokens.Colors.interactiveDefault)
            .frame(
                minWidth: DesignTokens.Dimensions.minTouchTarget,
                minHeight: DesignTokens.Dimensions.minTouchTarget
            )
            .contentShape(Rectangle())
            .accessibilityLabel("Settings")
            .help("Settings")
        }
    }

    /// Original FineTune Output/Input pill selector. Keep this component visually
    /// identical to the upstream control while retaining current accessibility and
    /// Reduce Motion behavior.
    private var deviceTabsHeader: some View {
        let iconSize: CGFloat = 13
        let buttonSize: CGFloat = 26

        return HStack(spacing: 2) {
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75)) {
                    onSelectDirection(.output)
                }
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: iconSize, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        direction.isInput
                            ? DesignTokens.Colors.textTertiary
                            : DesignTokens.Colors.textPrimary
                    )
                    .frame(width: buttonSize, height: buttonSize)
                    .background {
                        if !direction.isInput {
                            RoundedRectangle(cornerRadius: DesignTokens.Dimensions.buttonRadius)
                                .fill(DesignTokens.Colors.glassFillStrong)
                                .matchedGeometryEffect(id: "deviceToggle", in: deviceToggleNamespace)
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Output")
            .accessibilityAddTraits(!direction.isInput ? .isSelected : [])
            .help("Output Devices")

            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75)) {
                    onSelectDirection(.input)
                }
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: iconSize, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        direction.isInput
                            ? DesignTokens.Colors.textPrimary
                            : DesignTokens.Colors.textTertiary
                    )
                    .frame(width: buttonSize, height: buttonSize)
                    .background {
                        if direction.isInput {
                            RoundedRectangle(cornerRadius: DesignTokens.Dimensions.buttonRadius)
                                .fill(DesignTokens.Colors.glassFillStrong)
                                .matchedGeometryEffect(id: "deviceToggle", in: deviceToggleNamespace)
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Input")
            .accessibilityAddTraits(direction.isInput ? .isSelected : [])
            .help("Input Devices")
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Dimensions.buttonRadius + 3)
                .fill(DesignTokens.Colors.glassFill)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Dimensions.buttonRadius + 3)
                        .strokeBorder(DesignTokens.Colors.glassRowBorder, lineWidth: 0.5)
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Audio direction")
        .accessibilityValue(Text(direction.isInput ? "Input" : "Output"))
    }

    private var managementTitle: LocalizedStringResource {
        if isManaging { return "Done managing" }
        return direction.isInput ? "Manage Input" : "Manage Output"
    }
}

private struct PopupFooter: View {
    @State private var isSupportHovered = false

    var body: some View {
        HStack {
            Button {
                NSWorkspace.shared.open(DesignTokens.Links.support)
            } label: {
                Label("Donate", systemImage: isSupportHovered ? "heart.fill" : "heart")
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(
                isSupportHovered
                    ? Color(nsColor: .systemPink)
                    : DesignTokens.Colors.textTertiary
            )
            .frame(minHeight: DesignTokens.Dimensions.minTouchTarget)
            .contentShape(Rectangle())
            .onHover { isSupportHovered = $0 }
            .accessibilityLabel("Donate to FineTune")
            .help("Donate to FineTune")

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 6) {
                    Text("Quit")
                    Text("⌘Q")
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .font(DesignTokens.Typography.caption)
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .accessibilityLabel("Quit FineTune")
            .help("Quit FineTune (⌘Q)")
        }
    }
}
