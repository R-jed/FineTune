// FineTune/Views/Components/SectionHeader.swift
import SwiftUI

/// A styled section header for organizing content.
/// Static FineTune-owned labels stay localizable; dynamic/external labels must opt into verbatim rendering.
struct SectionHeader: View {
    private enum Title {
        case localized(LocalizedStringResource)
        case verbatim(String)
    }

    private let title: Title

    init(title: LocalizedStringResource) {
        self.title = .localized(title)
    }

    init(verbatimTitle: String) {
        self.title = .verbatim(verbatimTitle)
    }

    private var text: Text {
        switch title {
        case .localized(let resource):
            Text(resource)
        case .verbatim(let value):
            Text(verbatim: value)
        }
    }

    var body: some View {
        text.sectionHeaderStyle()
    }
}

// MARK: - Previews

#Preview("Section Headers") {
    ComponentPreviewContainer {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            SectionHeader(title: "Output Devices")

            SectionHeader(title: "Apps")

            SectionHeader(title: "Active Applications")
        }
    }
}
