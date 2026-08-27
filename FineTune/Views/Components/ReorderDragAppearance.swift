import SwiftUI

/// Shared visual and pointer treatment for vertical row reordering.
/// Reorder data/state stays with the owning list; this file only standardizes
/// the drag affordance and the appearance of the actively dragged row.
struct ReorderDragHandle: View {
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(DesignTokens.Colors.textTertiary)
            .frame(width: 20, height: DesignTokens.Dimensions.rowContentHeight)
            .contentShape(Rectangle())
            .reorderDragTarget(
                minimumDistance: 0,
                onChanged: onChanged,
                onEnded: onEnded
            )
            .help("Drag to reorder")
            .accessibilityHidden(true)
    }
}

private struct ReorderDragAppearanceModifier: ViewModifier {
    let isDragging: Bool
    let offset: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .shadow(
                color: Color.black.opacity(isDragging ? 0.18 : 0),
                radius: isDragging ? 8 : 0,
                x: 0,
                y: isDragging ? 4 : 0
            )
            .zIndex(isDragging ? 10 : 0)
            .transaction { transaction in
                if isDragging {
                    transaction.animation = nil
                }
            }
    }
}

private struct ReorderDragTargetModifier: ViewModifier {
    let minimumDistance: CGFloat
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    func body(content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: minimumDistance)
                .onChanged { value in
                    onChanged(value.translation.height)
                }
                .onEnded { _ in
                    onEnded()
                }
        )
    }
}

extension View {
    func reorderDragAppearance(isDragging: Bool, offset: CGFloat) -> some View {
        modifier(ReorderDragAppearanceModifier(isDragging: isDragging, offset: offset))
    }

    func reorderDragTarget(
        minimumDistance: CGFloat = 2,
        onChanged: @escaping (CGFloat) -> Void,
        onEnded: @escaping () -> Void
    ) -> some View {
        modifier(
            ReorderDragTargetModifier(
                minimumDistance: minimumDistance,
                onChanged: onChanged,
                onEnded: onEnded
            )
        )
    }
}
