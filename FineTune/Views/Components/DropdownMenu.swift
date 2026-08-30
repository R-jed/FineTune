// FineTune/Views/Components/DropdownMenu.swift
import SwiftUI

/// A reusable dropdown menu component with height restriction support
struct DropdownMenu<Item: Identifiable, Label: View, ItemContent: View>: View where Item.ID: Hashable {
    let items: [Item]
    let selectedItem: Item?
    let maxVisibleItems: Int?
    let width: CGFloat
    let popoverWidth: CGFloat?
    let onSelect: (Item) -> Void
    @ViewBuilder let label: (Item?) -> Label
    @ViewBuilder let itemContent: (Item, Bool) -> ItemContent

    @State private var isExpanded = false
    @State private var isButtonHovered = false

    @Environment(\.appearancePreference) private var appearancePreference
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Configuration
    private let itemHeight: CGFloat = 26
    private let itemSpacing: CGFloat = 2
    private let verticalPadding: CGFloat = 12  // 6 top + 6 bottom
    private let cornerRadius: CGFloat = 8

    private var effectivePopoverWidth: CGFloat {
        popoverWidth ?? width
    }

    private var menuHeight: CGFloat {
        let itemCount = CGFloat(items.count)
        let totalSpacing = itemSpacing * Swift.max(0, itemCount - 1)
        if let maxItems = maxVisibleItems {
            let visibleCount = min(itemCount, CGFloat(maxItems))
            let visibleSpacing = itemSpacing * Swift.max(0, visibleCount - 1)
            return visibleCount * itemHeight + visibleSpacing + verticalPadding
        }
        return itemCount * itemHeight + totalSpacing + verticalPadding
    }

    private func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else { return }
        withAnimation(reduceMotion ? nil : DesignTokens.Animation.selection) {
            isExpanded = expanded
        }
    }

    // MARK: - Trigger Button
    private var triggerButton: some View {
        Button {
            setExpanded(!isExpanded)
        } label: {
            HStack {
                label(selectedItem)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? -180 : 0))
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 4)
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Dimensions.buttonRadius)
                .fill(DesignTokens.Surface.raised)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Dimensions.buttonRadius)
                .strokeBorder(
                    isButtonHovered ? DesignTokens.Stroke.hover : DesignTokens.Stroke.resting,
                    lineWidth: 0.5
                )
        }
        .onHover { isButtonHovered = $0 }
        .animation(reduceMotion ? nil : DesignTokens.Animation.hover, value: isButtonHovered)
        .accessibilityValue(isExpanded ? Text("Expanded") : Text("Collapsed"))
    }

    // MARK: - Body
    var body: some View {
        triggerButton
            .background(
                PopoverHost(
                    isPresented: $isExpanded,
                    preferredColorScheme: appearancePreference.swiftUIColorScheme,
                    nsAppearance: appearancePreference.nsAppearance
                ) {
                    DropdownContentView(
                        items: items,
                        selectedItem: selectedItem,
                        width: effectivePopoverWidth,
                        menuHeight: menuHeight,
                        itemHeight: itemHeight,
                        itemSpacing: itemSpacing,
                        cornerRadius: cornerRadius,
                        onSelect: { item in
                            onSelect(item)
                            setExpanded(false)
                        },
                        itemContent: itemContent
                    )
                }
            )
    }
}

// MARK: - Dropdown Content View

private struct DropdownContentView<Item: Identifiable, ItemContent: View>: View where Item.ID: Hashable {
    let items: [Item]
    let selectedItem: Item?
    let width: CGFloat
    let menuHeight: CGFloat
    let itemHeight: CGFloat
    let itemSpacing: CGFloat
    let cornerRadius: CGFloat
    let onSelect: (Item) -> Void
    @ViewBuilder let itemContent: (Item, Bool) -> ItemContent

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: itemSpacing) {
                ForEach(items) { item in
                    DropdownMenuItem(
                        item: item,
                        isSelected: selectedItem?.id == item.id,
                        itemHeight: itemHeight,
                        onSelect: onSelect,
                        itemContent: itemContent
                    )
                    .id(item.id)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 5)
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollPosition(id: .constant(selectedItem?.id), anchor: .center)
        .frame(width: width, height: menuHeight)
        .background(
            VisualEffectBackground(material: .menu, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(DesignTokens.Colors.glassBorder, lineWidth: 0.5)
        }
    }
}

// MARK: - Dropdown Menu Item (with hover tracking)

private struct DropdownMenuItem<Item: Identifiable, ItemContent: View>: View where Item.ID: Hashable {
    let item: Item
    let isSelected: Bool
    let itemHeight: CGFloat
    let onSelect: (Item) -> Void
    @ViewBuilder let itemContent: (Item, Bool) -> ItemContent

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            onSelect(item)
        } label: {
            itemContent(item, isSelected)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .frame(height: itemHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isHovered ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .whenHovered { isHovered = $0 }
        .animation(reduceMotion ? nil : DesignTokens.Animation.hover, value: isHovered)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Grouped Dropdown Menu

/// A dropdown menu with section headers for grouped/categorized items
struct GroupedDropdownMenu<Section: Identifiable & Hashable, Item: Identifiable, Label: View, ItemContent: View>: View
    where Item.ID: Hashable {

    let sections: [Section]
    let itemsForSection: (Section) -> [Item]
    let sectionTitle: (Section) -> Text
    let selectedItem: Item?
    let maxHeight: CGFloat
    let width: CGFloat
    let popoverWidth: CGFloat?
    let onSelect: (Item) -> Void
    @ViewBuilder let label: (Item?) -> Label
    @ViewBuilder let itemContent: (Item, Bool) -> ItemContent

    @State private var isExpanded = false
    @State private var isButtonHovered = false

    @Environment(\.appearancePreference) private var appearancePreference
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Configuration
    private let itemHeight: CGFloat = 22
    private let sectionHeaderHeight: CGFloat = 24
    private let cornerRadius: CGFloat = 8

    private var effectivePopoverWidth: CGFloat {
        popoverWidth ?? width
    }

    private func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else { return }
        withAnimation(reduceMotion ? nil : DesignTokens.Animation.selection) {
            isExpanded = expanded
        }
    }

    // MARK: - Trigger Button
    private var triggerButton: some View {
        Button {
            setExpanded(!isExpanded)
        } label: {
            HStack {
                label(selectedItem)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? -180 : 0))
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 4)
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Dimensions.buttonRadius)
                .fill(DesignTokens.Surface.raised)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Dimensions.buttonRadius)
                .strokeBorder(
                    isButtonHovered ? DesignTokens.Stroke.hover : DesignTokens.Stroke.resting,
                    lineWidth: 0.5
                )
        }
        .onHover { isButtonHovered = $0 }
        .animation(reduceMotion ? nil : DesignTokens.Animation.hover, value: isButtonHovered)
        .accessibilityValue(isExpanded ? Text("Expanded") : Text("Collapsed"))
    }

    // MARK: - Body
    var body: some View {
        triggerButton
            .background(
                PopoverHost(
                    isPresented: $isExpanded,
                    preferredColorScheme: appearancePreference.swiftUIColorScheme,
                    nsAppearance: appearancePreference.nsAppearance
                ) {
                    GroupedDropdownContentView(
                        sections: sections,
                        itemsForSection: itemsForSection,
                        sectionTitle: sectionTitle,
                        selectedItem: selectedItem,
                        width: effectivePopoverWidth,
                        maxHeight: maxHeight,
                        itemHeight: itemHeight,
                        sectionHeaderHeight: sectionHeaderHeight,
                        cornerRadius: cornerRadius,
                        onSelect: { item in
                            onSelect(item)
                            setExpanded(false)
                        },
                        itemContent: itemContent
                    )
                }
            )
    }
}

// MARK: - Grouped Dropdown Content View

private struct GroupedDropdownContentView<Section: Identifiable & Hashable, Item: Identifiable, ItemContent: View>: View
    where Item.ID: Hashable {

    let sections: [Section]
    let itemsForSection: (Section) -> [Item]
    let sectionTitle: (Section) -> Text
    let selectedItem: Item?
    let width: CGFloat
    let maxHeight: CGFloat
    let itemHeight: CGFloat
    let sectionHeaderHeight: CGFloat
    let cornerRadius: CGFloat
    let onSelect: (Item) -> Void
    @ViewBuilder let itemContent: (Item, Bool) -> ItemContent

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(sections) { section in
                    sectionTitle(section)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.top, section.id == sections.first?.id ? 2 : 8)
                        .padding(.bottom, 2)
                        .frame(height: sectionHeaderHeight, alignment: .bottomLeading)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(itemsForSection(section)) { item in
                        DropdownMenuItem(
                            item: item,
                            isSelected: selectedItem?.id == item.id,
                            itemHeight: itemHeight,
                            onSelect: onSelect,
                            itemContent: itemContent
                        )
                    }
                }
            }
            .padding(5)
        }
        .scrollIndicators(.hidden)
        .frame(width: width)
        .frame(maxHeight: maxHeight)
        .background(
            VisualEffectBackground(material: .menu, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(DesignTokens.Colors.glassBorder, lineWidth: 0.5)
        }
    }
}
