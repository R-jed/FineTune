// FineTune/Views/Rows/AppVisibilityEditRow.swift
import SwiftUI

/// Compact row used by the secondary edit layer to manage app visibility.
/// Pinning stays on the primary app row so this surface has one responsibility.
struct AppVisibilityEditRow: View {
    let icon: NSImage
    let name: String
    let isHidden: Bool
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
                .opacity(isHidden ? 0.4 : 1.0)

            Text(name)
                .font(DesignTokens.Typography.rowName)
                .lineLimit(1)
                .help(name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(
                    isHidden
                        ? DesignTokens.Colors.textSecondary
                        : DesignTokens.Colors.textPrimary
                )

            Button(action: onToggleVisibility) {
                Image(systemName: isHidden ? "eye.slash" : "eye")
                    .font(.system(size: 13))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(eyeColor)
                    .frame(
                        minWidth: DesignTokens.Dimensions.minTouchTarget,
                        minHeight: DesignTokens.Dimensions.minTouchTarget
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isEyeHovered = $0 }
            .accessibilityLabel(isHidden ? "Hidden apps" : "Hide app")
            .help(isHidden ? "Hidden apps" : "Hide app")
            .animation(DesignTokens.Animation.quick, value: isEyeHovered)
        }
        .frame(height: DesignTokens.Dimensions.rowContentHeight)
        .hoverableRow()
    }

    private var eyeColor: Color {
        if isHidden {
            return isEyeHovered
                ? DesignTokens.Colors.textPrimary
                : DesignTokens.Colors.textSecondary
        }
        return isEyeHovered
            ? DesignTokens.Colors.interactiveHover
            : DesignTokens.Colors.interactiveDefault
    }
}
