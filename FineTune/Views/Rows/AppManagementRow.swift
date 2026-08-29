import AppKit
import SwiftUI

/// Output-edit App visibility row. Pin and reorder stay on the primary App list.
struct AppManagementRow: View {
    let icon: NSImage
    let name: String
    let isIgnored: Bool
    let onToggleVisibility: () -> Void

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

            Text(verbatim: name)
                .font(DesignTokens.Typography.rowName)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(
                    isIgnored
                        ? DesignTokens.Colors.textSecondary
                        : DesignTokens.Colors.textPrimary
                )

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
}
