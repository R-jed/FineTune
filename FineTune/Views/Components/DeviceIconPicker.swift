// FineTune/Views/Components/DeviceIconPicker.swift
import SwiftUI
import AppKit
import Foundation

/// Popover content for choosing a device's icon override. Selection applies
/// immediately via `onSelect` and the popover stays open for further browsing;
/// `onSelect(nil)` restores the automatic icon.
struct DeviceIconPicker: View {
    let device: AudioDevice
    let isInputDevice: Bool
    let currentOverride: String?
    let onSelect: (String?) -> Void

    @Environment(\.locale) private var locale
    @State private var query = ""
    @State private var driverIconPresent = false

    private static let columns = Array(
        repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.xs),
        count: 6
    )

    var body: some View {
        let highlighted = highlightedSymbol

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            searchField

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    if trimmedQuery.isEmpty {
                        gridSection(title: "Suggested", symbols: suggestedSymbols, highlighted: highlighted)
                        ForEach(DeviceIconCatalog.categories) { category in
                            if let title = Self.localizedCategoryTitle(for: category.name) {
                                gridSection(
                                    title: title,
                                    symbols: category.entries.map(\.symbol),
                                    highlighted: highlighted
                                )
                            } else {
                                gridSection(
                                    verbatimTitle: category.name,
                                    symbols: category.entries.map(\.symbol),
                                    highlighted: highlighted
                                )
                            }
                        }
                    } else {
                        searchResults(highlighted: highlighted)
                    }
                }
            }
            .contentMargins(.trailing, DesignTokens.Spacing.sm, for: .scrollContent)
            .frame(height: 300)
            .scrollIndicators(.never)

            Button("Restore Default") {
                onSelect(nil)
            }
            .controlSize(.small)
            .disabled(currentOverride == nil)
            .frame(maxWidth: .infinity)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(width: 300)
        .task(id: device.uid) {
            driverIconPresent = DeviceIconCache.shared.icon(for: device.uid) {
                device.id.readDeviceIcon()
            } != nil
        }
    }

    // MARK: - Sections

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    static func localizedCategoryTitle(for name: String) -> LocalizedStringResource? {
        switch name {
        case "Headphones & Earbuds": return "Headphones & Earbuds"
        case "Speakers": return "Speakers"
        case "Computers & Displays": return "Computers & Displays"
        case "Microphones": return "Microphones"
        case "Connectors & Other": return "Connectors & Other"
        default: return nil
        }
    }

    static func localizedCategoryTitle(forSymbol symbol: String) -> LocalizedStringResource? {
        guard let category = DeviceIconCatalog.categories.first(where: { category in
            category.entries.contains(where: { $0.symbol == symbol })
        }) else { return nil }
        return localizedCategoryTitle(for: category.name)
    }

    static func matchingEntries(query: String, locale: Locale) -> [DeviceIconCatalog.Entry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return DeviceIconCatalog.allEntries }

        var matches = DeviceIconCatalog.matching(trimmed)
        var seen = Set(matches.map(\.symbol))

        for category in DeviceIconCatalog.categories {
            guard let title = localizedCategoryTitle(for: category.name) else { continue }
            var localizedTitleResource = title
            localizedTitleResource.locale = locale
            let localizedTitle = String(localized: localizedTitleResource)
            guard localizedTitle.localizedCaseInsensitiveContains(trimmed)
                    || category.name.localizedCaseInsensitiveContains(trimmed) else { continue }

            for entry in category.entries where seen.insert(entry.symbol).inserted {
                matches.append(entry)
            }
        }

        return matches
    }

    @ViewBuilder
    private func searchResults(highlighted: String?) -> some View {
        let hits = Self.matchingEntries(query: trimmedQuery, locale: locale).map(\.symbol)
        if hits.isEmpty {
            Text("No matching icons")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, DesignTokens.Spacing.md)
        } else {
            grid(symbols: hits, highlighted: highlighted)
        }
    }

    @ViewBuilder
    private func gridSection(
        title: LocalizedStringResource,
        symbols: [String],
        highlighted: String?
    ) -> some View {
        SectionHeader(title: title)
            .frame(maxWidth: .infinity, alignment: .leading)
        grid(symbols: symbols, highlighted: highlighted)
    }

    @ViewBuilder
    private func gridSection(
        verbatimTitle: String,
        symbols: [String],
        highlighted: String?
    ) -> some View {
        SectionHeader(verbatimTitle: verbatimTitle)
            .frame(maxWidth: .infinity, alignment: .leading)
        grid(symbols: symbols, highlighted: highlighted)
    }

    private func grid(symbols: [String], highlighted: String?) -> some View {
        LazyVGrid(columns: Self.columns, spacing: DesignTokens.Spacing.xs) {
            ForEach(symbols, id: \.self) { symbol in
                IconCell(
                    symbol: symbol,
                    isHighlighted: symbol == highlighted,
                    onSelect: { onSelect(symbol) }
                )
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
            TextField("Search icons", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(DesignTokens.Surface.recessed)
        )
    }

    // MARK: - Symbol Resolution

    private var suggestedSymbols: [String] {
        Self.composeSuggested(
            leading: isInputDevice ? device.id.suggestedInputIconSymbol() : nil,
            shared: DeviceIconCatalog.suggested(
                forName: device.name,
                transport: device.id.readTransportType()
            )
        )
    }

    static func composeSuggested(leading: String?, shared: [String]) -> [String] {
        var result: [String] = leading.map { [$0] } ?? []
        for symbol in shared where !result.contains(symbol) {
            result.append(symbol)
        }
        return result
    }

    private var highlightedSymbol: String? {
        Self.highlightSymbol(
            currentOverride: currentOverride,
            automaticIsSymbol: !driverIconPresent,
            automaticSymbol: isInputDevice
                ? device.id.suggestedInputIconSymbol()
                : device.id.suggestedIconSymbol()
        )
    }

    /// Nil when the automatic icon is a driver-provided image — no grid cell is current then.
    static func highlightSymbol(
        currentOverride: String?,
        automaticIsSymbol: Bool,
        automaticSymbol: String
    ) -> String? {
        if let currentOverride { return currentOverride }
        return automaticIsSymbol ? automaticSymbol : nil
    }
}

// MARK: - Icon Cell

/// Per-cell hover state (not a shared hovered-symbol on the picker) because the
/// Suggested section repeats catalog symbols — identity by symbol would light
/// up both twins at once.
private struct IconCell: View {
    let symbol: String
    let isHighlighted: Bool
    let onSelect: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var descriptor: Text {
        if let category = DeviceIconPicker.localizedCategoryTitle(forSymbol: symbol) {
            return Text(category) + Text(verbatim: ", \(symbol)")
        }
        return Text(verbatim: symbol)
    }

    var body: some View {
        Button(action: onSelect) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .symbolRenderingMode(.hierarchical)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(
                            isHighlighted ? DesignTokens.Colors.accentPrimary : Color.clear,
                            lineWidth: 1.5
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : DesignTokens.Animation.hover, value: isHovered)
        .help(descriptor)
        .accessibilityLabel(Text("Choose device icon") + Text(verbatim: ": ") + descriptor)
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }

    private var fill: Color {
        if isHighlighted { return DesignTokens.Surface.emphasized }
        if isHovered { return DesignTokens.Surface.hover }
        return .clear
    }
}

// MARK: - Previews

#Preview("DeviceIconPicker") {
    ComponentPreviewContainer {
        DeviceIconPicker(
            device: MockData.sampleDevices[1],
            isInputDevice: false,
            currentOverride: "gamecontroller.fill",
            onSelect: { _ in }
        )
    }
}
