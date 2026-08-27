// FineTune/Models/AppListPresentationOrder.swift
import Foundation

/// Pure ordering seam for Apps shown in the popup.
///
/// This first version intentionally mirrors the existing global persisted order so
/// U1 grouping tests can expose the current mixed pinned/normal behavior before the
/// production integration changes it.
struct AppListPresentationOrder {
    static func ordered(
        _ apps: [DisplayableApp],
        pinnedIdentifiers: Set<String>,
        persistedOrder: [String]
    ) -> [DisplayableApp] {
        let orderRank = Dictionary(
            uniqueKeysWithValues: persistedOrder.enumerated().map { ($1, $0) }
        )

        return apps.sorted { lhs, rhs in
            let lhsRank = orderRank[lhs.id]
            let rhsRank = orderRank[rhs.id]
            if let lhsRank, let rhsRank { return lhsRank < rhsRank }
            if lhsRank != nil { return true }
            if rhsRank != nil { return false }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}