import AppKit
import Testing
@testable import FineTune

@Suite("U1 app list presentation order")
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

    @Test("pinned Apps form the top group while both groups preserve persisted order")
    func pinnedGroupComesFirstWithStableOrder() {
        let normalA = app("com.test.normal-a", name: "Normal A")
        let pinnedA = app("com.test.pinned-a", name: "Pinned A")
        let normalB = app("com.test.normal-b", name: "Normal B")
        let pinnedB = app("com.test.pinned-b", name: "Pinned B")
        let visible = [normalA, pinnedA, normalB, pinnedB]
        let persisted = visible.map(\.id)

        let ordered = AppListPresentationOrder.ordered(
            visible,
            pinnedIdentifiers: [pinnedA.id, pinnedB.id],
            persistedOrder: persisted
        )

        #expect(ordered.map(\.id) == [pinnedA.id, pinnedB.id, normalA.id, normalB.id])
    }

    @Test("pin and unpin change group membership without rewriting latent manual order")
    func pinStateOnlyChangesPresentationGroup() {
        let normalA = app("com.test.normal-a", name: "Normal A")
        let candidate = app("com.test.candidate", name: "Candidate")
        let normalB = app("com.test.normal-b", name: "Normal B")
        let visible = [normalA, candidate, normalB]
        let persisted = visible.map(\.id)

        let pinned = AppListPresentationOrder.ordered(
            visible,
            pinnedIdentifiers: [candidate.id],
            persistedOrder: persisted
        )
        let unpinned = AppListPresentationOrder.ordered(
            visible,
            pinnedIdentifiers: [],
            persistedOrder: persisted
        )

        #expect(pinned.map(\.id) == [candidate.id, normalA.id, normalB.id])
        #expect(unpinned.map(\.id) == persisted)
    }

    @Test("unseen Apps use deterministic alphabetical fallback inside each group")
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

    @Test("accessible reorder returns adjacent target only inside the same pin group")
    func accessibleReorderTargetStaysInsideGroup() {
        let order = ["pinned-a", "pinned-b", "normal-a", "normal-b"]
        let pinned: Set<String> = ["pinned-a", "pinned-b"]

        #expect(AppListPresentationOrder.reorderTarget(
            for: "pinned-a",
            direction: 1,
            orderedIdentifiers: order,
            pinnedIdentifiers: pinned
        ) == "pinned-b")
        #expect(AppListPresentationOrder.reorderTarget(
            for: "normal-b",
            direction: -1,
            orderedIdentifiers: order,
            pinnedIdentifiers: pinned
        ) == "normal-a")
        #expect(AppListPresentationOrder.reorderTarget(
            for: "pinned-b",
            direction: 1,
            orderedIdentifiers: order,
            pinnedIdentifiers: pinned
        ) == nil)
        #expect(AppListPresentationOrder.reorderTarget(
            for: "normal-a",
            direction: -1,
            orderedIdentifiers: order,
            pinnedIdentifiers: pinned
        ) == nil)
    }

    @Test("accessible reorder omits actions at the outer list boundaries")
    func accessibleReorderTargetStopsAtListBoundary() {
        let order = ["pinned-a", "normal-a"]
        let pinned: Set<String> = ["pinned-a"]

        #expect(AppListPresentationOrder.reorderTarget(
            for: "pinned-a",
            direction: -1,
            orderedIdentifiers: order,
            pinnedIdentifiers: pinned
        ) == nil)
        #expect(AppListPresentationOrder.reorderTarget(
            for: "normal-a",
            direction: 1,
            orderedIdentifiers: order,
            pinnedIdentifiers: pinned
        ) == nil)
    }
}

@Suite("U1 app reorder group boundary")
@MainActor
struct AppReorderGroupBoundaryTests {
    @Test("SettingsManager runtime order presents pinned Apps first")
    func runtimePresentationOrderGroupsPinnedApps() {
        let manager = SettingsManager(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
        )
        let normalA = "com.test.normal-a"
        let pinnedA = "com.test.pinned-a"
        let normalB = "com.test.normal-b"
        let pinnedB = "com.test.pinned-b"
        let latentOrder = [normalA, pinnedA, normalB, pinnedB]

        manager.moveApp(normalA, to: normalA, currentOrder: latentOrder)
        manager.pinApp(
            pinnedA,
            info: PinnedAppInfo(persistenceIdentifier: pinnedA, displayName: "Pinned A", bundleID: pinnedA)
        )
        manager.pinApp(
            pinnedB,
            info: PinnedAppInfo(persistenceIdentifier: pinnedB, displayName: "Pinned B", bundleID: pinnedB)
        )

        #expect(manager.appOrder == [pinnedA, pinnedB, normalA, normalB])
    }

    @Test("pin and unpin preserve the latent manual order used by runtime presentation")
    func runtimePinMembershipPreservesLatentOrder() {
        let manager = SettingsManager(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
        )
        let normalA = "com.test.normal-a"
        let candidate = "com.test.candidate"
        let normalB = "com.test.normal-b"
        let latentOrder = [normalA, candidate, normalB]

        manager.moveApp(normalA, to: normalA, currentOrder: latentOrder)
        manager.pinApp(
            candidate,
            info: PinnedAppInfo(persistenceIdentifier: candidate, displayName: "Candidate", bundleID: candidate)
        )
        #expect(manager.appOrder == [candidate, normalA, normalB])

        manager.unpinApp(candidate)
        #expect(manager.appOrder == latentOrder)
    }

    @Test("drag reorder cannot cross the pinned group boundary")
    func crossGroupMoveIsRejected() {
        let manager = SettingsManager(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
        )
        let coordinator = AppListCoordinator(settingsManager: manager)
        let pinnedID = "com.test.pinned"
        let normalID = "com.test.normal"
        let pinnedInfo = PinnedAppInfo(
            persistenceIdentifier: pinnedID,
            displayName: "Pinned",
            bundleID: pinnedID
        )

        manager.pinApp(pinnedID, info: pinnedInfo)
        manager.moveApp(normalID, to: pinnedID, currentOrder: [normalID, pinnedID])
        let before = manager.appOrder

        coordinator.moveApp(normalID, to: pinnedID, currentOrder: [pinnedID, normalID])

        #expect(manager.appOrder == before)
    }

    @Test("drag reorder still works inside the pinned group")
    func samePinnedGroupMoveStillWorks() {
        let manager = SettingsManager(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
        )
        let coordinator = AppListCoordinator(settingsManager: manager)
        let first = PinnedAppInfo(
            persistenceIdentifier: "com.test.first",
            displayName: "First",
            bundleID: "com.test.first"
        )
        let second = PinnedAppInfo(
            persistenceIdentifier: "com.test.second",
            displayName: "Second",
            bundleID: "com.test.second"
        )

        manager.pinApp(first.persistenceIdentifier, info: first)
        manager.pinApp(second.persistenceIdentifier, info: second)
        coordinator.moveApp(
            second.persistenceIdentifier,
            to: first.persistenceIdentifier,
            currentOrder: [first.persistenceIdentifier, second.persistenceIdentifier]
        )

        #expect(manager.getPinnedAppInfo() == [second, first])
    }
}
