import AppKit
import Testing
@testable import FineTune

@Suite("Pinned app list presentation order")
struct AppListPresentationOrderTests {
    private func app(_ identifier: String, name: String) -> DisplayableApp {
        .active(
            AudioApp(
                id: pid_t(abs(identifier.hashValue % 30_000) + 1),
                processObjectIDs: [],
                name: name,
                icon: NSImage(),
                bundleID: identifier,
                isAudioActive: false
            )
        )
    }

    @Test("pinned Apps form the top group while both groups preserve latent rank")
    func pinnedGroupComesFirstWithStableOrder() {
        let normalA = app("com.test.normal-a", name: "Normal A")
        let pinnedA = app("com.test.pinned-a", name: "Pinned A")
        let normalB = app("com.test.normal-b", name: "Normal B")
        let pinnedB = app("com.test.pinned-b", name: "Pinned B")
        let visible = [normalA, pinnedA, normalB, pinnedB]

        let ordered = AppListPresentationOrder.ordered(
            visible,
            pinnedIdentifiers: [pinnedA.id, pinnedB.id],
            persistedOrder: visible.map(\.id)
        )

        #expect(ordered.map(\.id) == [pinnedA.id, pinnedB.id, normalA.id, normalB.id])
    }

    @Test("unseen apps use deterministic alphabetical fallback inside each group")
    func unseenAppsSortAlphabeticallyWithinGroups() {
        let normalZ = app("com.test.normal-z", name: "Zulu")
        let pinnedZ = app("com.test.pinned-z", name: "Pinned Zulu")
        let normalA = app("com.test.normal-a", name: "Alpha")
        let pinnedA = app("com.test.pinned-a", name: "Pinned Alpha")

        let ordered = AppListPresentationOrder.ordered(
            [normalZ, pinnedZ, normalA, pinnedA],
            pinnedIdentifiers: [pinnedZ.id, pinnedA.id],
            persistedOrder: []
        )

        #expect(ordered.map(\.id) == [pinnedA.id, pinnedZ.id, normalA.id, normalZ.id])
    }

    @Test("duplicate persisted identifiers keep their first rank without trapping")
    func duplicatePersistedIdentifiersAreTolerated() {
        let a = app("com.test.a", name: "Alpha")
        let b = app("com.test.b", name: "Bravo")

        let ordered = AppListPresentationOrder.ordered(
            [a, b],
            pinnedIdentifiers: [],
            persistedOrder: [b.id, b.id, a.id]
        )

        #expect(ordered.map(\.id) == [b.id, a.id])
    }

    @Test("reorder treats the section header as a reversible membership step")
    func sectionBoundaryIsItsOwnReorderStep() throws {
        var order = ["A", "B", "C", "D"]
        var pinned: Set<String> = ["A", "B"]

        var step = try #require(AppListPresentationOrder.reorderStep(
            for: "B",
            direction: 1,
            orderedIdentifiers: order,
            pinnedIdentifiers: pinned
        ))
        #expect(step.orderedIdentifiers == order)
        #expect(!step.pinned)
        #expect(step.crossesSectionBoundary)
        pinned.remove("B")

        step = try #require(AppListPresentationOrder.reorderStep(
            for: "B",
            direction: 1,
            orderedIdentifiers: order,
            pinnedIdentifiers: pinned
        ))
        order = step.orderedIdentifiers
        #expect(order == ["A", "C", "B", "D"])
        #expect(!step.crossesSectionBoundary)

        step = try #require(AppListPresentationOrder.reorderStep(
            for: "B",
            direction: -1,
            orderedIdentifiers: order,
            pinnedIdentifiers: pinned
        ))
        order = step.orderedIdentifiers
        #expect(order == ["A", "B", "C", "D"])

        step = try #require(AppListPresentationOrder.reorderStep(
            for: "B",
            direction: -1,
            orderedIdentifiers: order,
            pinnedIdentifiers: pinned
        ))
        #expect(step.orderedIdentifiers == order)
        #expect(step.pinned)
        #expect(step.crossesSectionBoundary)
    }

    @Test("section crossing works when the destination section is empty")
    func sectionBoundarySupportsEmptyDestination() {
        let order = ["A", "B"]

        #expect(AppListPresentationOrder.reorderStep(
            for: "A",
            direction: -1,
            orderedIdentifiers: order,
            pinnedIdentifiers: []
        )?.pinned == true)
        #expect(AppListPresentationOrder.reorderStep(
            for: "B",
            direction: 1,
            orderedIdentifiers: order,
            pinnedIdentifiers: ["A", "B"]
        )?.pinned == false)
    }

    @Test("hidden or absent apps stay attached to their previous visible predecessor")
    func mergePreservesInvisibleAnchors() {
        let latent = ["A", "hidden", "B", "C"]

        let merged = AppListPresentationOrder.mergingVisibleOrder(
            ["B", "C", "A"],
            into: latent
        )

        #expect(merged == ["B", "C", "A", "hidden"])
    }

    @Test("prefix and multiple latent IDs remain stable while visible apps move")
    func mergePreservesPrefixAndMultipleLatentIDs() {
        let latent = ["prefix", "A", "h1", "h2", "B", "suffix"]

        let merged = AppListPresentationOrder.mergingVisibleOrder(
            ["B", "A"],
            into: latent
        )

        #expect(merged == ["prefix", "B", "suffix", "A", "h1", "h2"])
    }

    @Test("newly seen visible apps are seeded into the latent order")
    func mergeSeedsNewVisibleApps() {
        let merged = AppListPresentationOrder.mergingVisibleOrder(
            ["B", "A"],
            into: ["hidden-prefix", "A"]
        )

        #expect(merged == ["hidden-prefix", "B", "A"])
    }

    @Test("cross-section placement moves only the dragged latent block")
    func placementPreservesInterleavedHistory() throws {
        let merged = try #require(AppListPresentationOrder.mergingPlacement(
            identifier: "B",
            visibleOrder: ["P1", "B", "P2", "A"],
            pinned: true,
            currentPinnedIdentifiers: ["P1", "P2"],
            into: ["P1", "A", "P2", "B"]
        ))

        #expect(merged == ["P1", "A", "B", "P2"])
    }

    @Test("new pinned app is inserted at its section rank without flattening existing history")
    func newPlacementPreservesExistingRelations() throws {
        let merged = try #require(AppListPresentationOrder.mergingPlacement(
            identifier: "N",
            visibleOrder: ["P", "N", "A", "B"],
            pinned: true,
            currentPinnedIdentifiers: ["P"],
            into: ["A", "P", "B"]
        ))

        #expect(merged == ["A", "P", "N", "B"])
    }

    @Test("moving a visible app carries its invisible latent anchors")
    func placementCarriesInvisibleAnchorBlock() throws {
        let merged = try #require(AppListPresentationOrder.mergingPlacement(
            identifier: "A",
            visibleOrder: ["B", "C", "A"],
            pinned: false,
            currentPinnedIdentifiers: [],
            into: ["A", "hidden", "B", "C"]
        ))

        #expect(merged == ["B", "C", "A", "hidden"])
    }

}
