import SwiftUI

/// Native drag source used by editable App and device rows.
///
/// SwiftUI owns the lifted drag preview and pointer coordinates. The owning
/// list decides whether a drop is semantically valid and performs the order
/// mutation once the drop is accepted.
struct ReorderDragHandle: View {
    let payload: String

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: DesignTokens.Dimensions.rowContentHeight)
            .contentShape(Rectangle())
            .draggable(payload)
            .help("Drag to reorder")
            .accessibilityHidden(true)
    }
}
