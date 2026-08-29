// FineTune/Views/Rows/DeviceEditRow.swift
import SwiftUI
import AppKit

/// Device-management row with a native drag handle, visible move alternatives,
/// icon+name, DEFAULT badge, hide toggle, and an info/close button that expands the
/// Device Inspector pane. Icon opens the icon picker; name+badge is the
/// tap region for expand — siblings keep their own gestures.
struct DeviceEditRow<ExpandedContent: View>: View {
    let device: AudioDevice
    var iconOverrideSymbol: String? = nil
    let priorityIndex: Int
    let isDefault: Bool
    let isInputDevice: Bool
    let deviceCount: Int
    let isExpanded: Bool
    let isHidden: Bool
    let isReordering: Bool
    let reorderOffset: CGFloat
    let onReorderChanged: (CGFloat) -> Void
    let onReorderEnded: () -> Void
    let onReorder: (Int) -> Void
    var onToggleExpand: (() -> Void)? = nil
    var onToggleHidden: (() -> Void)? = nil
    var onIconSelect: ((String?) -> Void)? = nil
    @ViewBuilder let expandedContent: () -> ExpandedContent

    @State private var isInfoButtonHovered = false
    @State private var showingIconPicker = false
    @State private var isIconHovered = false
    @State private var isHideButtonHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var displayIcon: NSImage? {
        DeviceIconResolver.displayIcon(
            overrideSymbol: iconOverrideSymbol,
            automatic: device.icon,
            deviceName: device.name
        )
    }

    private var detailsAccessibilityLabel: LocalizedStringResource {
        isExpanded ? "Collapse device details" : "Expand device details"
    }

    private var hideHelpText: LocalizedStringResource {
        if isDefault { return "Cannot hide the default device" }
        return isHidden ? "Show in main view" : "Hide from main view"
    }

    private var hideAccessibilityLabel: LocalizedStringResource {
        isHidden ? "Show in main view" : "Hide from main view"
    }

    private var inspectorHelpText: LocalizedStringResource {
        isExpanded ? "Close device inspector" : "Device inspector"
    }

    private var inspectorAccessibilityLabel: LocalizedStringResource {
        isExpanded ? "Close device inspector" : "Open device inspector"
    }

    var body: some View {
        accessibleReorderActions(
            ExpandableGlassRow(isExpanded: isExpanded) {
                headerRow
                    .opacity(isHidden && !isDefault ? 0.5 : 1.0)
                    .animation(.easeOut(duration: 0.2), value: isHidden)
            } expandedContent: {
                expandedContent()
            }
        )
        .continuousReorderAppearance(
            isDragging: isReordering,
            offset: reorderOffset
        )
    }

    private func accessibleReorderActions<Content: View>(_ content: Content) -> some View {
        let moveUpTarget = DeviceReorderAccessibility.targetIndex(
            currentIndex: priorityIndex,
            direction: -1,
            count: deviceCount
        )
        let moveDownTarget = DeviceReorderAccessibility.targetIndex(
            currentIndex: priorityIndex,
            direction: 1,
            count: deviceCount
        )

        return content.accessibilityActions {
            if let moveUpTarget {
                Button("Move Up") { onReorder(moveUpTarget) }
            }
            if let moveDownTarget {
                Button("Move Down") { onReorder(moveDownTarget) }
            }
        }
    }

    private var infoButtonColor: Color {
        if isExpanded {
            return DesignTokens.Colors.interactiveActive
        } else if isInfoButtonHovered {
            return DesignTokens.Colors.interactiveHover
        } else {
            return DesignTokens.Colors.interactiveDefault
        }
    }

    private var headerRow: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ReorderDragHandle(
                onChanged: onReorderChanged,
                onEnded: onReorderEnded
            )

            iconControl

            deviceIdentity

            if onToggleHidden != nil {
                hideToggleButton
            }

            if onToggleExpand != nil {
                infoButton
            }
        }
        .frame(height: DesignTokens.Dimensions.rowContentHeight)
    }

    private var deviceIdentityContent: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
                Text(verbatim: device.name)
                    .font(DesignTokens.Typography.rowName)
                    .lineLimit(1)
                    .help(Text(verbatim: "\(device.name)\n\(device.uid)"))

                if isDefault {
                    Text("DEFAULT")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(DesignTokens.Surface.emphasized)
                        )
                }

                Spacer()
        }
    }

    @ViewBuilder
    private var deviceIdentity: some View {
        if let onToggleExpand {
            deviceIdentityContent
            .contentShape(Rectangle())
            .onTapGesture { onToggleExpand() }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text(detailsAccessibilityLabel))
        } else {
            deviceIdentityContent
        }
    }

    @ViewBuilder
    private var iconControl: some View {
        if onIconSelect != nil {
            iconButton
        } else {
            deviceIcon
        }
    }

    private var iconButton: some View {
        Button {
            showingIconPicker = true
        } label: {
            deviceIcon
            .overlay(alignment: .bottomTrailing) {
                if isIconHovered {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 11))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, DesignTokens.Colors.accentPrimary)
                        .offset(x: 3, y: 3)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isIconHovered = $0 }
        .animation(DesignTokens.Animation.hover, value: isIconHovered)
        .help("Change icon")
        .accessibilityLabel("Change icon")
        .popover(isPresented: $showingIconPicker, arrowEdge: .bottom) {
            DeviceIconPicker(
                device: device,
                isInputDevice: isInputDevice,
                currentOverride: iconOverrideSymbol,
                onSelect: { symbol in onIconSelect?(symbol) }
            )
        }
    }

    private var deviceIcon: some View {
        Group {
            if let icon = displayIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: isInputDevice ? "mic" : "speaker.wave.2")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: DesignTokens.Dimensions.iconSize, height: DesignTokens.Dimensions.iconSize)
    }

    private var hideToggleButton: some View {
        Button {
            onToggleHidden?()
        } label: {
            Image(systemName: isHidden ? "eye.slash" : "eye")
                .font(.system(size: 12))
                .foregroundStyle(hideSymbolColor)
                .frame(
                    minWidth: DesignTokens.Dimensions.minTouchTarget,
                    minHeight: DesignTokens.Dimensions.minTouchTarget
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDefault)
        .onHover { isHideButtonHovered = !isDefault && $0 }
        .help(hideHelpText)
        .accessibilityLabel(Text(hideAccessibilityLabel))
    }

    private var hideSymbolColor: Color {
        if isDefault {
            return DesignTokens.Colors.textTertiary.opacity(0.4)
        }
        if isHidden {
            return DesignTokens.Colors.mutedIndicator
        }
        return isHideButtonHovered
            ? DesignTokens.Colors.interactiveHover
            : DesignTokens.Colors.textTertiary
    }

    private var infoButton: some View {
        Button {
            onToggleExpand?()
        } label: {
            ZStack {
                Image(systemName: "info.circle")
                    .opacity(isExpanded ? 0 : 1)
                    .rotationEffect(.degrees(reduceMotion ? 0 : (isExpanded ? 90 : 0)))

                Image(systemName: "xmark")
                    .opacity(isExpanded ? 1 : 0)
                    .rotationEffect(.degrees(reduceMotion ? 0 : (isExpanded ? 0 : -90)))
            }
            .font(.system(size: 12))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(infoButtonColor)
            .frame(
                minWidth: DesignTokens.Dimensions.minTouchTarget,
                minHeight: DesignTokens.Dimensions.minTouchTarget
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isInfoButtonHovered = $0 }
        .help(inspectorHelpText)
        .accessibilityLabel(Text(inspectorAccessibilityLabel))
        .animation(reduceMotion ? nil : DesignTokens.Animation.hover, value: isInfoButtonHovered)
    }
}

enum DeviceReorderAccessibility {
    static func targetIndex(currentIndex: Int, direction: Int, count: Int) -> Int? {
        guard direction == -1 || direction == 1 else { return nil }
        let targetIndex = currentIndex + direction
        guard (0..<count).contains(targetIndex) else { return nil }
        return targetIndex
    }

    static func reorderedIdentifiers(
        _ orderedIdentifiers: [String],
        moving identifier: String,
        to targetIndex: Int
    ) -> [String]? {
        guard let sourceIndex = orderedIdentifiers.firstIndex(of: identifier),
              orderedIdentifiers.indices.contains(targetIndex),
              sourceIndex != targetIndex else {
            return nil
        }

        var result = orderedIdentifiers
        let movedIdentifier = result.remove(at: sourceIndex)
        result.insert(movedIdentifier, at: min(targetIndex, result.count))
        return result
    }
}

#Preview("DeviceEditRow Tap Carveout") {
    DeviceEditRowTapCarveoutPreview()
}

struct DeviceEditRowTapCarveoutPreview: View {
    @State private var lastEvent: String = "Tap anywhere to test"
    @State private var expandedUID: String?

    var body: some View {
        PreviewContainer {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text(lastEvent)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

                DeviceEditRow(
                    device: MockData.sampleDevices[0],
                    priorityIndex: 0,
                    isDefault: true,
                    isInputDevice: false,
                    deviceCount: 3,
                    isExpanded: expandedUID == MockData.sampleDevices[0].uid,
                    isHidden: false,
                    isReordering: false,
                    reorderOffset: 0,
                    onReorderChanged: { _ in },
                    onReorderEnded: {},
                    onReorder: { newIndex in
                        lastEvent = "Reorder to \(newIndex + 1)"
                    },
                    onToggleExpand: {
                        withAnimation(.easeOut(duration: 0.16)) {
                            let uid = MockData.sampleDevices[0].uid
                            expandedUID = (expandedUID == uid) ? nil : uid
                            lastEvent = "Toggled expand → \(expandedUID ?? "nil")"
                        }
                    },
                    onToggleHidden: {
                        lastEvent = "Toggle hidden"
                    },
                    expandedContent: {
                        Text("Expanded detail content here")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                    }
                )
            }
        }
    }
}
