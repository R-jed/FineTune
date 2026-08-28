import AppKit
import SwiftUI

/// Output-edit management row for App visibility, pin state, and in-group ordering.
struct AppManagementRow: View {
    let icon: NSImage
    let name: String
    let isIgnored: Bool
    var isPinned: Bool? = nil
    let onToggleVisibility: () -> Void
    var onTogglePin: (() -> Void)? = nil
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil

    @State private var isEyeHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(
                    width: DesignTokens.Dimensions.iconSize,
                    height: DesignTokens.Dimensions.iconSize
                )
                .opacity(isIgnored ? 0.55 : 1)

            accessibleName

            if let onMoveUp {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(
                            minWidth: DesignTokens.Dimensions.minTouchTarget,
                            minHeight: DesignTokens.Dimensions.minTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Move app up")
                .accessibilityLabel("Move app up")
            }

            if let onMoveDown {
                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(
                            minWidth: DesignTokens.Dimensions.minTouchTarget,
                            minHeight: DesignTokens.Dimensions.minTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Move app down")
                .accessibilityLabel("Move app down")
            }

            if let isPinned, let onTogglePin {
                Button(action: onTogglePin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin.slash")
                        .font(.system(size: 11))
                        .frame(
                            minWidth: DesignTokens.Dimensions.minTouchTarget,
                            minHeight: DesignTokens.Dimensions.minTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Unpin app" : "Pin app")
                .accessibilityLabel(isPinned ? "Unpin app" : "Pin app")
            }

            Button(action: onToggleVisibility) {
                HoverMorphSymbol(
                    primarySymbol: isIgnored ? "eye.slash" : "eye",
                    isHovered: isEyeHovered,
                    primaryColor: isIgnored
                        ? DesignTokens.Colors.textSecondary
                        : DesignTokens.Colors.interactiveDefault,
                    secondaryColor: isIgnored
                        ? DesignTokens.Colors.textPrimary
                        : DesignTokens.Colors.interactiveHover,
                    font: .system(size: 13)
                )
                .frame(
                    minWidth: DesignTokens.Dimensions.minTouchTarget,
                    minHeight: DesignTokens.Dimensions.minTouchTarget
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isEyeHovered = $0 }
            .help(isIgnored ? "Show app" : "Hide app")
            .accessibilityLabel(isIgnored ? "Show app" : "Hide app")
        }
        .frame(height: DesignTokens.Dimensions.rowContentHeight)
        .hoverableRow()
    }

    @ViewBuilder
    private var accessibleName: some View {
        let label = Text(verbatim: name)
            .font(DesignTokens.Typography.rowName)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(
                isIgnored
                    ? DesignTokens.Colors.textSecondary
                    : DesignTokens.Colors.textPrimary
            )

        if let onMoveUp, let onMoveDown {
            label
                .accessibilityAction(named: Text("Move Up"), onMoveUp)
                .accessibilityAction(named: Text("Move Down"), onMoveDown)
        } else if let onMoveUp {
            label.accessibilityAction(named: Text("Move Up"), onMoveUp)
        } else if let onMoveDown {
            label.accessibilityAction(named: Text("Move Down"), onMoveDown)
        } else {
            label
        }
    }
}
