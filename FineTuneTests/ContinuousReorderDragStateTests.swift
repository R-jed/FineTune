import CoreGraphics
import Testing
@testable import FineTune

@Suite("Continuous interactive reorder state")
struct ContinuousReorderDragStateTests {
    @Test("drag follows pointer until crossing the adjacent midpoint")
    func midpointCrossing() {
        var state = ContinuousReorderDragState()
        state.update(id: "B", rawTranslation: 19)
        #expect(state.consumeCrossingIfNeeded(rowExtent: 40, index: 1, count: 4) == nil)
        #expect(state.effectiveTranslation == 19)

        state.update(id: "B", rawTranslation: 21)
        #expect(state.consumeCrossingIfNeeded(rowExtent: 40, index: 1, count: 4) == 1)
        #expect(state.effectiveTranslation == -19)
    }

    @Test("one gesture can continuously cross multiple rows")
    func repeatedCrossings() {
        var state = ContinuousReorderDragState()
        state.update(id: "A", rawTranslation: 101)

        var index = 0
        var crossings: [Int] = []
        while let direction = state.consumeCrossingIfNeeded(
            rowExtent: 40,
            index: index,
            count: 4
        ) {
            crossings.append(direction)
            index += direction
        }

        #expect(crossings == [1, 1, 1])
        #expect(index == 3)
        #expect(state.effectiveTranslation == -19)
    }

    @Test("section boundary consumes the real header extent independently from row swaps")
    func sectionBoundaryCrossing() {
        var state = ContinuousReorderDragState()
        state.update(id: "B", rawTranslation: 10)

        let crossedBoundary = state.consumeCrossingIfNeeded(extent: 18, direction: 1)
        #expect(crossedBoundary)
        #expect(state.effectiveTranslation == -8)
    }

    @Test("one gesture can cross a section header and then a row without residual jump")
    func boundaryThenRowCrossing() {
        var state = ContinuousReorderDragState()
        state.update(id: "B", rawTranslation: 40)

        let crossedBoundary = state.consumeCrossingIfNeeded(extent: 18, direction: 1)
        let crossedRow = state.consumeCrossingIfNeeded(extent: 40, direction: 1)
        #expect(crossedBoundary)
        #expect(crossedRow)
        #expect(state.effectiveTranslation == -18)
    }

    @Test("ending a drag clears all pointer bookkeeping")
    func resetClearsState() {
        var state = ContinuousReorderDragState()
        state.update(id: "B", rawTranslation: -25)
        _ = state.consumeCrossingIfNeeded(rowExtent: 40, index: 1, count: 3)
        state.reset()

        #expect(state.draggedID == nil)
        #expect(state.effectiveTranslation == 0)
    }
}
