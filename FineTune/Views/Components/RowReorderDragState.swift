import CoreGraphics

/// Pointer-drag bookkeeping for vertically reordered rows.
///
/// `originAdjustment` is advanced by one row extent after every adjacent swap.
/// Subtracting it from the raw gesture translation keeps the dragged row under
/// the pointer even though its layout slot has moved.
struct RowReorderDragState: Equatable {
    private(set) var draggedID: String?
    private(set) var rawTranslation: CGFloat = 0
    private(set) var originAdjustment: CGFloat = 0

    var effectiveTranslation: CGFloat {
        guard draggedID != nil else { return 0 }
        return rawTranslation - originAdjustment
    }

    mutating func update(id: String, rawTranslation: CGFloat) {
        if draggedID != id {
            draggedID = id
            self.rawTranslation = 0
            originAdjustment = 0
        }
        self.rawTranslation = rawTranslation
    }

    /// Returns -1 or +1 after consuming one adjacent midpoint crossing.
    /// Call repeatedly so a fast pointer move can cross several rows.
    mutating func consumeSwapIfNeeded(
        rowExtent: CGFloat,
        index: Int,
        count: Int
    ) -> Int? {
        guard draggedID != nil, rowExtent > 0, count > 1 else { return nil }

        let midpoint = rowExtent / 2
        if effectiveTranslation > midpoint, index + 1 < count {
            originAdjustment += rowExtent
            return 1
        }
        if effectiveTranslation < -midpoint, index > 0 {
            originAdjustment -= rowExtent
            return -1
        }
        return nil
    }

    mutating func reset() {
        draggedID = nil
        rawTranslation = 0
        originAdjustment = 0
    }
}
