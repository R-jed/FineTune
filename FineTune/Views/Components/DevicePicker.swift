// FineTune/Views/Components/DevicePicker.swift
import SwiftUI

/// A styled device picker dropdown with "System" option and single/multi mode support
struct DevicePicker: View {
    /// Visual style for the trigger button.
    /// - `.full`: bordered material pill with icon + text + chevron (used in Settings).
    /// - `.iconOnly`: square borderless icon button with hover highlight (used in app rows).
    enum TriggerStyle {
        case full
        case iconOnly
    }

    let devices: [AudioDevice]
    var deviceIconOverrides: [String: String] = [:]
    let selectedDeviceUID: String
    let selectedDeviceUIDs: Set<String>
    let isFollowingDefault: Bool
    let defaultDeviceUID: String?
    let mode: DeviceSelectionMode
    let onModeChange: (DeviceSelectionMode) -> Void
    let onDeviceSelected: (String) -> Void
    let onDevicesSelected: (Set<String>) -> Void
    let onSelectFollowDefault: () -> Void
    let showModeToggle: Bool

    @State private var isExpanded = false
    @State private var isButtonHovered = false

    @Environment(\.appearancePreference) private var appearancePreference
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Local state mirrors props for popover reactivity
    @State private var currentMode: DeviceSelectionMode = .single
    @State private var currentSelectedUIDs: Set<String> = []

    // Configuration
    let triggerWidth: CGFloat
    var triggerStyle: TriggerStyle = .full
    private let popoverWidth: CGFloat = 210
    private let itemHeight: CGFloat = 26
    private let itemSpacing: CGFloat = 2
    private let cornerRadius: CGFloat = 8

    enum MenuItem: Identifiable, Equatable {
        case systemAudio
        case device(AudioDevice)

        var id: String {
            switch self {
            case .systemAudio: return "__system_audio__"
            case .device(let device): return device.uid
            }
        }
    }

    private var menuItems: [MenuItem] {
        [.systemAudio] + devices.map { .device($0) }
    }

    /// Selected devices intersected with the currently-rendered list.
    private var validMultiSelections: [AudioDevice] {
        devices.filter { selectedDeviceUIDs.contains($0.uid) }
    }

    /// Display text for the trigger button. Static copy stays localizable while
    /// device names remain verbatim external data.
    private var triggerText: Text {
        switch mode {
        case .single:
            return singleModeText
        case .multi:
            let count = validMultiSelections.count
            if count == 0 {
                return singleModeText
            }
            if count == 1 {
                return Text(verbatim: validMultiSelections[0].name)
            }
            return Text(verbatim: "\(count) ") + Text("devices")
        }
    }

    private var singleModeText: Text {
        if isFollowingDefault {
            return Text("System Audio")
        } else if let device = devices.first(where: { $0.uid == selectedDeviceUID }) {
            return Text(verbatim: device.name)
        }
        return Text("Select")
    }

    @ViewBuilder
    private var triggerIcon: some View {
        switch mode {
        case .single:
            singleModeIcon
        case .multi:
            let valid = validMultiSelections
            if let first = valid.first {
                multiModeIcon(firstDevice: first, count: valid.count)
            } else {
                Image(systemName: "hifispeaker.2.fill")
                    .font(.system(size: 16))
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }

    private func displayIcon(for device: AudioDevice) -> NSImage? {
        DeviceIconResolver.displayIcon(
            overrideSymbol: deviceIconOverrides[device.uid],
            automatic: device.icon,
            deviceName: device.name
        )
    }

    @ViewBuilder
    private func deviceIcon(_ device: AudioDevice) -> some View {
        if let icon = displayIcon(for: device) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 18))
                .symbolRenderingMode(.hierarchical)
        }
    }

    @ViewBuilder
    private var singleModeIcon: some View {
        if isFollowingDefault {
            Image(systemName: "globe")
                .font(.system(size: 15))
                .symbolRenderingMode(.hierarchical)
        } else if let device = devices.first(where: { $0.uid == selectedDeviceUID }),
                  let icon = displayIcon(for: device) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 15))
                .symbolRenderingMode(.hierarchical)
        }
    }

    @ViewBuilder
    private func multiModeIcon(firstDevice: AudioDevice, count: Int) -> some View {
        deviceIcon(firstDevice)
            .overlay(alignment: .bottomTrailing) {
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 0.5)
                    .background(Capsule().fill(DesignTokens.Colors.accentPrimary))
                    .offset(x: 4, y: 3)
            }
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
                    dropdownContent
                }
            )
            .onChange(of: mode) { _, newMode in
                currentMode = newMode
            }
            .onChange(of: selectedDeviceUIDs) { _, newUIDs in
                currentSelectedUIDs = newUIDs
            }
            .onAppear {
                currentMode = mode
                currentSelectedUIDs = selectedDeviceUIDs
            }
    }

    // MARK: - Trigger Button

    @ViewBuilder
    private var triggerButton: some View {
        switch triggerStyle {
        case .full:
            fullTriggerButton
        case .iconOnly:
            iconOnlyTriggerButton
        }
    }

    private var fullTriggerButton: some View {
        Button {
            setExpanded(!isExpanded)
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    triggerIcon
                    triggerText
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? -180 : 0))
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 4)
            .frame(width: triggerWidth)
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
        .help(triggerText)
        .accessibilityLabel("Device")
        .accessibilityValue(triggerText)
    }

    private var iconOnlyTriggerButton: some View {
        Button {
            setExpanded(!isExpanded)
        } label: {
            triggerIcon
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Dimensions.buttonRadius)
                        .fill(iconOnlyBackgroundFill)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(triggerText)
        .accessibilityLabel("Device")
        .accessibilityValue(triggerText)
        .onHover { isButtonHovered = $0 }
        .animation(reduceMotion ? nil : DesignTokens.Animation.hover, value: isButtonHovered)
    }

    private var iconOnlyBackgroundFill: Color {
        if isExpanded {
            return Color.primary.opacity(0.12)
        } else if isButtonHovered {
            return Color.primary.opacity(0.08)
        } else {
            return Color.clear
        }
    }

    // MARK: - Dropdown Content

    private var dropdownContent: some View {
        VStack(spacing: 0) {
            if showModeToggle {
                ModeToggle(mode: Binding(
                    get: { currentMode },
                    set: { newMode in
                        currentMode = newMode
                        onModeChange(newMode)
                    }
                ))
                .padding(.horizontal, DesignTokens.Spacing.xs + 2)
                .padding(.top, DesignTokens.Spacing.xs + 2)
                .padding(.bottom, DesignTokens.Spacing.xs)

                Divider()
                    .padding(.horizontal, 6)
            }

            ScrollView(.vertical) {
                LazyVStack(spacing: itemSpacing) {
                    ForEach(menuItems) { item in
                        deviceRow(for: item)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 5)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 220)
        }
        .frame(width: popoverWidth)
        .background(
            VisualEffectBackground(material: .menu, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(DesignTokens.Colors.glassBorder, lineWidth: 0.5)
        }
    }

    // MARK: - Device Row

    @ViewBuilder
    private func deviceRow(for item: MenuItem) -> some View {
        let isSystemAudio = item.id == "__system_audio__"
        let isDisabled = currentMode == .multi && isSystemAudio
        let isSelected = isItemSelected(item)

        DevicePickerRow(
            item: item,
            resolvedIcon: {
                if case .device(let device) = item {
                    return displayIcon(for: device)
                }
                return nil
            }(),
            isSelected: isSelected,
            isDisabled: isDisabled,
            isMultiMode: currentMode == .multi,
            isDefaultDevice: {
                if case .device(let device) = item {
                    return device.uid == defaultDeviceUID
                }
                return false
            }(),
            onTap: {
                handleItemTap(item)
            }
        )
    }

    private func isItemSelected(_ item: MenuItem) -> Bool {
        switch currentMode {
        case .single:
            if case .systemAudio = item {
                return isFollowingDefault
            } else if case .device(let device) = item {
                return !isFollowingDefault && device.uid == selectedDeviceUID
            }
            return false
        case .multi:
            if case .device(let device) = item {
                return currentSelectedUIDs.contains(device.uid)
            }
            return false
        }
    }

    private func setExpanded(_ expanded: Bool) {
        guard isExpanded != expanded else { return }
        withAnimation(reduceMotion ? nil : DesignTokens.Animation.selection) {
            isExpanded = expanded
        }
    }

    private func handleItemTap(_ item: MenuItem) {
        switch currentMode {
        case .single:
            switch item {
            case .systemAudio:
                onSelectFollowDefault()
            case .device(let device):
                onDeviceSelected(device.uid)
            }
            setExpanded(false)

        case .multi:
            guard case .device(let device) = item else { return }
            var newSelection = currentSelectedUIDs
            if newSelection.contains(device.uid) {
                newSelection.remove(device.uid)
            } else {
                newSelection.insert(device.uid)
            }
            currentSelectedUIDs = newSelection
            onDevicesSelected(newSelection)
        }
    }
}

// MARK: - Device Picker Row

private struct DevicePickerRow: View {
    let item: DevicePicker.MenuItem
    let resolvedIcon: NSImage?
    let isSelected: Bool
    let isDisabled: Bool
    let isMultiMode: Bool
    let isDefaultDevice: Bool
    let onTap: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var rowLabel: Text {
        switch item {
        case .systemAudio:
            return Text("System Audio")
        case .device(let device):
            return Text(verbatim: device.name)
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                selectionIndicator
                itemIcon
                itemText
                Spacer()

                if isDefaultDevice {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .accessibilityHidden(true)
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(isDisabled ? DesignTokens.Colors.textQuaternary : .primary)
            .padding(.horizontal, 8)
            .frame(height: 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovered && !isDisabled ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .whenHovered { isHovered = $0 }
        .animation(reduceMotion ? nil : DesignTokens.Animation.hover, value: isHovered)
        .help(rowLabel)
        .accessibilityLabel(rowLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isDefaultDevice ? Text("Default device") : Text(""))
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        if isMultiMode {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.textTertiary)
                .frame(width: 16)
                .accessibilityHidden(true)
        } else {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.accentPrimary)
                    .frame(width: 16)
                    .accessibilityHidden(true)
            } else {
                Spacer()
                    .frame(width: 16)
            }
        }
    }

    @ViewBuilder
    private var itemIcon: some View {
        switch item {
        case .systemAudio:
            Image(systemName: "globe")
                .font(.system(size: 13))
                .frame(width: 16)
                .foregroundStyle(isDisabled ? DesignTokens.Colors.textQuaternary : DesignTokens.Colors.textSecondary)
                .accessibilityHidden(true)
        case .device:
            if let icon = resolvedIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .opacity(isDisabled ? 0.4 : 1.0)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 13))
                    .frame(width: 16)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var itemText: some View {
        switch item {
        case .systemAudio:
            VStack(alignment: .leading, spacing: 1) {
                Text("System Audio")
                if isDisabled {
                    Text("Not available in multi mode")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textQuaternary)
                } else {
                    Text("Follows macOS default")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
        case .device(let device):
            Text(verbatim: device.name)
                .lineLimit(1)
                .help(Text(verbatim: device.name))
        }
    }
}

// MARK: - Routing Subtitle Helper

extension DevicePicker {
    static func routingSubtitle(
        devices: [AudioDevice],
        selectedDeviceUID: String,
        selectedDeviceUIDs: Set<String>,
        isFollowingDefault: Bool,
        mode: DeviceSelectionMode
    ) -> Text? {
        switch mode {
        case .single:
            if isFollowingDefault { return nil }
            guard let device = devices.first(where: { $0.uid == selectedDeviceUID }) else { return nil }
            return Text(verbatim: device.name)
        case .multi:
            let valid = devices.filter { selectedDeviceUIDs.contains($0.uid) }
            switch valid.count {
            case 0:
                return Text("Multi")
            case 1:
                return Text("Multi") + Text(verbatim: " · \(valid[0].name)")
            default:
                return Text("Multi") + Text(verbatim: " · \(valid.count) ") + Text("devices")
            }
        }
    }
}

// MARK: - Convenience Initializer for Backward Compatibility

extension DevicePicker {
    init(
        devices: [AudioDevice],
        deviceIconOverrides: [String: String] = [:],
        selectedDeviceUID: String,
        isFollowingDefault: Bool,
        defaultDeviceUID: String?,
        triggerWidth: CGFloat = 105,
        onDeviceSelected: @escaping (String) -> Void,
        onSelectFollowDefault: @escaping () -> Void
    ) {
        self.devices = devices
        self.deviceIconOverrides = deviceIconOverrides
        self.selectedDeviceUID = selectedDeviceUID
        self.selectedDeviceUIDs = []
        self.isFollowingDefault = isFollowingDefault
        self.defaultDeviceUID = defaultDeviceUID
        self.triggerWidth = triggerWidth
        self.mode = .single
        self.onModeChange = { _ in }
        self.onDeviceSelected = onDeviceSelected
        self.onDevicesSelected = { _ in }
        self.onSelectFollowDefault = onSelectFollowDefault
        self.showModeToggle = false
    }
}

// MARK: - Previews

#Preview("Device Picker - Single Mode") {
    ComponentPreviewContainer {
        VStack(spacing: DesignTokens.Spacing.md) {
            DevicePicker(
                devices: MockData.sampleDevices,
                selectedDeviceUID: MockData.sampleDevices[0].uid,
                isFollowingDefault: true,
                defaultDeviceUID: MockData.sampleDevices[0].uid,
                onDeviceSelected: { _ in },
                onSelectFollowDefault: {}
            )
        }
    }
}

#Preview("Device Picker - Multi Mode") {
    struct MultiModePreview: View {
        @State private var mode: DeviceSelectionMode = .multi
        @State private var selectedUIDs: Set<String> = []

        var body: some View {
            ComponentPreviewContainer {
                VStack(spacing: DesignTokens.Spacing.md) {
                    DevicePicker(
                        devices: MockData.sampleDevices,
                        selectedDeviceUID: MockData.sampleDevices[0].uid,
                        selectedDeviceUIDs: selectedUIDs,
                        isFollowingDefault: false,
                        defaultDeviceUID: MockData.sampleDevices[0].uid,
                        mode: mode,
                        onModeChange: { mode = $0 },
                        onDeviceSelected: { _ in },
                        onDevicesSelected: { selectedUIDs = $0 },
                        onSelectFollowDefault: {},
                        showModeToggle: true,
                        triggerWidth: 105
                    )

                    Text("Selected: \(selectedUIDs.count) devices")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    return MultiModePreview()
}

#Preview("Device Picker - Interactive") {
    struct MultiModePreview: View {
        @State private var mode: DeviceSelectionMode = .single
        @State private var selectedUID = ""
        @State private var selectedUIDs: Set<String> = []
        @State private var isFollowingDefault = true

        var body: some View {
            ComponentPreviewContainer {
                VStack(spacing: DesignTokens.Spacing.md) {
                    DevicePicker(
                        devices: MockData.sampleDevices,
                        selectedDeviceUID: selectedUID,
                        selectedDeviceUIDs: selectedUIDs,
                        isFollowingDefault: isFollowingDefault,
                        defaultDeviceUID: MockData.sampleDevices[0].uid,
                        mode: mode,
                        onModeChange: { newMode in
                            mode = newMode
                            if newMode == .multi {
                                isFollowingDefault = false
                            }
                        },
                        onDeviceSelected: { uid in
                            selectedUID = uid
                            isFollowingDefault = false
                        },
                        onDevicesSelected: { uids in
                            selectedUIDs = uids
                        },
                        onSelectFollowDefault: {
                            isFollowingDefault = true
                        },
                        showModeToggle: true,
                        triggerWidth: 105
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mode: \(mode == .single ? "Single" : "Multi")")
                        if mode == .single {
                            Text("Following default: \(isFollowingDefault ? "Yes" : "No")")
                            if !isFollowingDefault {
                                Text("Selected: \(selectedUID)")
                            }
                        } else {
                            Text("Selected: \(selectedUIDs.count) devices")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
    return MultiModePreview()
}
