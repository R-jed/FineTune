// FineTune/Models/AppListPresentationOrder.swift
import Foundation

/// Pure ordering seam for Apps shown in the popup.
///
/// Pinned and normal Apps are stable partitions of the same latent user order.
/// Pinning changes only presentation-group membership; it does not rewrite the
/// persisted relative order that should reappear if the App is later unpinned.
struct AppListPresentationOrder {
    static func ordered(
        _ apps: [DisplayableApp],
        pinnedIdentifiers: Set<String>,
        persistedOrder: [String]
    ) -> [DisplayableApp] {
        let orderRank = Dictionary(
            uniqueKeysWithValues: persistedOrder.enumerated().map { ($1, $0) }
        )

        func comesBefore(_ lhs: DisplayableApp, _ rhs: DisplayableApp) -> Bool {
            let lhsRank = orderRank[lhs.id]
            let rhsRank = orderRank[rhs.id]
            if let lhsRank, let rhsRank { return lhsRank < rhsRank }
            if lhsRank != nil { return true }
            if rhsRank != nil { return false }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }

        let pinned = apps
            .filter { pinnedIdentifiers.contains($0.id) }
            .sorted(by: comesBefore)
        let normal = apps
            .filter { !pinnedIdentifiers.contains($0.id) }
            .sorted(by: comesBefore)
        return pinned + normal
    }
}
