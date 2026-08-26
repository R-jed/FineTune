import Testing
import CoreGraphics
@testable import FineTune

@Suite("Row reorder drag state")
struct RowReorderDragStateTests {
    @Test("downward midpoint crossing swaps once and resets drag origin")
    func downwardCrossing() {
        var state = RowReorderDragState()
        state.update(id: "A", rawTranslation: 23)

        #expect(state.consumeSwapIfNeeded(rowExtent: 44, index: 0, count: 3) == 1)
        #expect(state.originAdjustment == 44)
        #expect(state.effectiveTranslation == -21)
    }

    @Test("fast downward move can consume multiple adjacent crossings")
    func fastDownwardMove() {
        var state = RowReorderDragState()
        state.update(id: "A", rawTranslation: 70)

        #expect(state.consumeSwapIfNeeded(rowExtent: 44, index: 0, count: 4) == 1)
        #expect(state.consumeSwapIfNeeded(rowExtent: 44, index: 1, count: 4) == 1)
        #expect(state.consumeSwapIfNeeded(rowExtent: 44, index: 2, count: 4) == nil)
        #expect(state.effectiveTranslation == -18)
    }

    @Test("upward midpoint crossing swaps once and resets drag origin")
    func upwardCrossing() {
        var state = RowReorderDragState()
        state.update(id: "C", rawTranslation: -23)

        #expect(state.consumeSwapIfNeeded(rowExtent: 44, index: 2, count: 3) == -1)
        #expect(state.originAdjustment == -44)
        #expect(state.effectiveTranslation == 21)
    }

    @Test("touching midpoint alone does not swap")
    func exactMidpointDoesNotSwap() {
        var state = RowReorderDragState()
        state.update(id: "A", rawTranslation: 22)

        #expect(state.consumeSwapIfNeeded(rowExtent: 44, index: 0, count: 2) == nil)
        #expect(state.effectiveTranslation == 22)
    }

    @Test("switching dragged row resets accumulated origin adjustment")
    func switchingDraggedRowResetsOrigin() {
        var state = RowReorderDragState()
        state.update(id: "A", rawTranslation: 70)
        #expect(state.consumeSwapIfNeeded(rowExtent: 44, index: 0, count: 3) == 1)

        state.update(id: "B", rawTranslation: 10)

        #expect(state.draggedID == "B")
        #expect(state.originAdjustment == 0)
        #expect(state.effectiveTranslation == 10)
    }

    @Test("reset clears active drag")
    func resetClearsState() {
        var state = RowReorderDragState()
        state.update(id: "A", rawTranslation: 15)
        state.reset()

        #expect(state.draggedID == nil)
        #expect(state.effectiveTranslation == 0)
        #expect(state.originAdjustment == 0)
    }
}
