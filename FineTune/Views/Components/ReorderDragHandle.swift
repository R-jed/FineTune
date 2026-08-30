import SwiftUI

/// Shared pointer handle for continuous interactive row reordering.
struct ReorderDragHandle: View {
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: DesignTokens.Dimensions.rowContentHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        onChanged(value.translation.height)
                    }
                    .onEnded { _ in
                        onEnded()
                    }
            )
            .help("Drag to reorder")
            .accessibilityHidden(true)
    }
}

/// Pointer bookkeeping for continuous vertical reordering.
///
/// The gesture translation is measured from the original pointer-down point.
/// Every accepted row crossing advances `consumedTranslation` by one row extent,
/// leaving `effectiveTranslation` as the residual distance inside the new slot.
/// The owning list mutates only transient/local order during the gesture.
struct ContinuousReorderDragState: Equatable {
    private(set) var draggedID: String?
    private(set) var rawTranslation: CGFloat = 0
    private(set) var consumedTranslation: CGFloat = 0

    var effectiveTranslation: CGFloat {
        guard draggedID != nil else { return 0 }
        return rawTranslation - consumedTranslation
    }

    mutating func update(id: String, rawTranslation: CGFloat) {
        if draggedID != id {
            draggedID = id
            self.rawTranslation = 0
            consumedTranslation = 0
        }
        self.rawTranslation = rawTranslation
    }

    mutating func consumeCrossingIfNeeded(
        rowExtent: CGFloat,
        index: Int,
        count: Int
    ) -> Int? {
        guard count > 1 else { return nil }
        if index + 1 < count,
           consumeCrossingIfNeeded(extent: rowExtent, direction: 1) {
            return 1
        }
        if index > 0,
           consumeCrossingIfNeeded(extent: rowExtent, direction: -1) {
            return -1
        }
        return nil
    }

    /// Consumes one caller-defined layout step. App reordering uses the actual
    /// section-header height for a membership transition and the row extent for
    /// a row swap, so both kinds of movement remain pointer-continuous.
    mutating func consumeCrossingIfNeeded(
        extent: CGFloat,
        direction: Int
    ) -> Bool {
        guard draggedID != nil,
              extent > 0,
              direction == -1 || direction == 1 else {
            return false
        }

        if direction > 0 {
            guard effectiveTranslation > extent / 2 else { return false }
            consumedTranslation += extent
            return true
        }

        guard effectiveTranslation < -(extent / 2) else { return false }
        consumedTranslation -= extent
        return true
    }

    mutating func reset() {
        draggedID = nil
        rawTranslation = 0
        consumedTranslation = 0
    }
}

private struct ContinuousReorderAppearanceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                if isDragging || reduceMotion {
                    transaction.animation = nil
                }
            }
    }
}

extension View {
    func continuousReorderAppearance(isDragging: Bool, offset: CGFloat) -> some View {
        modifier(ContinuousReorderAppearanceModifier(isDragging: isDragging, offset: offset))
    }
}
