// FineTune/Models/AppListPresentationOrder.swift
import Foundation

/// Pure ordering seam for currently visible Apps in the popup. The persisted order
/// remains one global latent sequence; pinning is only a stable presentation partition.
struct AppListPresentationOrder {
    struct ReorderStep: Equatable {
        let orderedIdentifiers: [String]
        let pinned: Bool
        let crossesSectionBoundary: Bool
    }

    static func ordered(
        _ apps: [DisplayableApp],
        pinnedIdentifiers: Set<String>,
        persistedOrder: [String]
    ) -> [DisplayableApp] {
        var orderRank: [String: Int] = [:]
        for (index, identifier) in persistedOrder.enumerated() where orderRank[identifier] == nil {
            orderRank[identifier] = index
        }

        func comesBefore(_ lhs: DisplayableApp, _ rhs: DisplayableApp) -> Bool {
            let lhsRank = orderRank[lhs.id]
            let rhsRank = orderRank[rhs.id]
            if let lhsRank, let rhsRank { return lhsRank < rhsRank }
            if lhsRank != nil { return true }
            if rhsRank != nil { return false }
            let nameOrder = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }

        let ranked = apps.sorted(by: comesBefore)
        let pinned = ranked.filter { pinnedIdentifiers.contains($0.id) }
        let applications = ranked.filter { !pinnedIdentifiers.contains($0.id) }
        return pinned + applications
    }

    /// Returns one semantic reorder step. The Pinned / Applications header is a
    /// real step of its own: crossing it changes only the dragged app's pin
    /// membership. Row order changes only when a row midpoint is crossed. This
    /// keeps pointer and accessibility reordering reversible at the section edge.
    static func reorderStep(
        for identifier: String,
        direction: Int,
        orderedIdentifiers: [String],
        pinnedIdentifiers: Set<String>
    ) -> ReorderStep? {
        guard direction == -1 || direction == 1,
              let sourceIndex = orderedIdentifiers.firstIndex(of: identifier) else {
            return nil
        }

        let pinnedCount = pinnedIdentifiers.intersection(orderedIdentifiers).count
        guard orderedIdentifiers.enumerated().allSatisfy({ index, id in
            pinnedIdentifiers.contains(id) == (index < pinnedCount)
        }) else {
            return nil
        }

        let sourcePinned = pinnedIdentifiers.contains(identifier)
        if direction < 0 {
            if sourcePinned {
                guard sourceIndex > 0 else { return nil }
                var order = orderedIdentifiers
                order.swapAt(sourceIndex, sourceIndex - 1)
                return ReorderStep(
                    orderedIdentifiers: order,
                    pinned: true,
                    crossesSectionBoundary: false
                )
            }

            if sourceIndex == pinnedCount {
                return ReorderStep(
                    orderedIdentifiers: orderedIdentifiers,
                    pinned: true,
                    crossesSectionBoundary: true
                )
            }

            guard sourceIndex > pinnedCount else { return nil }
            var order = orderedIdentifiers
            order.swapAt(sourceIndex, sourceIndex - 1)
            return ReorderStep(
                orderedIdentifiers: order,
                pinned: false,
                crossesSectionBoundary: false
            )
        }

        if sourcePinned {
            if sourceIndex == pinnedCount - 1 {
                return ReorderStep(
                    orderedIdentifiers: orderedIdentifiers,
                    pinned: false,
                    crossesSectionBoundary: true
                )
            }

            guard sourceIndex + 1 < pinnedCount else { return nil }
            var order = orderedIdentifiers
            order.swapAt(sourceIndex, sourceIndex + 1)
            return ReorderStep(
                orderedIdentifiers: order,
                pinned: true,
                crossesSectionBoundary: false
            )
        }

        guard sourceIndex + 1 < orderedIdentifiers.count else { return nil }
        var order = orderedIdentifiers
        order.swapAt(sourceIndex, sourceIndex + 1)
        return ReorderStep(
            orderedIdentifiers: order,
            pinned: false,
            crossesSectionBoundary: false
        )
    }

    /// Merges a user-chosen visible order back into the full latent order without
    /// incidentally reordering hidden or currently absent apps. Invisible IDs stay
    /// attached to the visible predecessor they followed before the move; IDs before
    /// the first visible app remain a stable prefix.
    static func mergingVisibleOrder(
        _ visibleOrder: [String],
        into latentOrder: [String]
    ) -> [String] {
        let visibleSet = Set(visibleOrder)
        var normalizedLatent: [String] = []
        var seen: Set<String> = []

        for identifier in latentOrder where seen.insert(identifier).inserted {
            normalizedLatent.append(identifier)
        }
        for identifier in visibleOrder where seen.insert(identifier).inserted {
            normalizedLatent.append(identifier)
        }

        var prefix: [String] = []
        var trailingByVisible: [String: [String]] = [:]
        var lastVisible: String?

        for identifier in normalizedLatent {
            if visibleSet.contains(identifier) {
                lastVisible = identifier
            } else if let lastVisible {
                trailingByVisible[lastVisible, default: []].append(identifier)
            } else {
                prefix.append(identifier)
            }
        }

        var result = prefix
        for identifier in visibleOrder {
            result.append(identifier)
            result.append(contentsOf: trailingByVisible[identifier] ?? [])
        }
        return result
    }

    /// Merges one user placement into the latent global order without flattening
    /// the Pinned / Applications presentation partition back into persistence.
    ///
    /// Only `identifier` may change its relative position. Invisible identifiers
    /// that followed it in the latent order travel with it as one anchor block;
    /// every other visible block keeps its historical relative order. The final
    /// visible order is used only to determine the identifier's rank inside its
    /// destination section.
    static func mergingPlacement(
        identifier: String,
        visibleOrder: [String],
        pinned: Bool,
        currentPinnedIdentifiers: Set<String>,
        into latentOrder: [String]
    ) -> [String]? {
        var seenVisible: Set<String> = []
        guard visibleOrder.allSatisfy({ seenVisible.insert($0).inserted }),
              visibleOrder.contains(identifier) else {
            return nil
        }

        var finalPinnedIdentifiers = currentPinnedIdentifiers
        if pinned {
            finalPinnedIdentifiers.insert(identifier)
        } else {
            finalPinnedIdentifiers.remove(identifier)
        }

        let visiblePinnedCount = visibleOrder.reduce(into: 0) { count, id in
            if finalPinnedIdentifiers.contains(id) { count += 1 }
        }
        guard visibleOrder.enumerated().allSatisfy({ index, id in
            finalPinnedIdentifiers.contains(id) == (index < visiblePinnedCount)
        }) else {
            return nil
        }

        let visibleSet = Set(visibleOrder)
        var normalizedLatent: [String] = []
        var seenLatent: Set<String> = []
        for id in latentOrder where seenLatent.insert(id).inserted {
            normalizedLatent.append(id)
        }
        let identifierWasLatent = seenLatent.contains(identifier)
        for id in visibleOrder where seenLatent.insert(id).inserted {
            normalizedLatent.append(id)
        }

        var prefix: [String] = []
        var blocks: [[String]] = []
        for id in normalizedLatent {
            if visibleSet.contains(id) {
                blocks.append([id])
            } else if blocks.isEmpty {
                prefix.append(id)
            } else {
                blocks[blocks.count - 1].append(id)
            }
        }

        guard let sourceIndex = blocks.firstIndex(where: { $0.first == identifier }) else {
            return nil
        }

        let desiredSectionOrder = visibleOrder.filter {
            finalPinnedIdentifiers.contains($0) == pinned
        }
        guard let desiredIndex = desiredSectionOrder.firstIndex(of: identifier) else {
            return nil
        }
        let desiredWithoutIdentifier = desiredSectionOrder.filter { $0 != identifier }
        let currentSectionWithoutIdentifier = blocks.compactMap(\.first).filter {
            $0 != identifier && finalPinnedIdentifiers.contains($0) == pinned
        }
        guard desiredWithoutIdentifier == currentSectionWithoutIdentifier else {
            return nil
        }

        let predecessor = desiredIndex > 0 ? desiredSectionOrder[desiredIndex - 1] : nil
        let successor = desiredIndex + 1 < desiredSectionOrder.count
            ? desiredSectionOrder[desiredIndex + 1]
            : nil

        let movedBlock = blocks.remove(at: sourceIndex)
        let lowerBound: Int
        if let predecessor,
           let predecessorIndex = blocks.firstIndex(where: { $0.first == predecessor }) {
            lowerBound = predecessorIndex + 1
        } else if predecessor != nil {
            return nil
        } else {
            lowerBound = 0
        }

        let upperBound: Int
        if let successor,
           let successorIndex = blocks.firstIndex(where: { $0.first == successor }) {
            upperBound = successorIndex
        } else if successor != nil {
            return nil
        } else {
            upperBound = blocks.count
        }

        guard lowerBound <= upperBound else { return nil }

        let preferredIndex: Int
        if identifierWasLatent {
            preferredIndex = min(sourceIndex, blocks.count)
        } else if predecessor != nil {
            preferredIndex = lowerBound
        } else if successor != nil {
            preferredIndex = upperBound
        } else {
            preferredIndex = blocks.count
        }
        let insertionIndex = min(max(preferredIndex, lowerBound), upperBound)
        blocks.insert(movedBlock, at: insertionIndex)

        return prefix + blocks.flatMap { $0 }
    }
}
