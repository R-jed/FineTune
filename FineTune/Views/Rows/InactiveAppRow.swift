import SwiftUI

/// Pinned app row whose process is currently unavailable. It shares the same
/// control grammar as an active row, but the VU meter is static and no live
/// process activation path exists.
struct InactiveAppRow: View {
    let appInfo: PinnedAppInfo
    let icon: NSImage
    let volume: Float
    let devices: [AudioDevice]
    let deviceIconOverrides: [String: String]
    let selectedDeviceUID: String?
    let selectedDeviceUIDs: Set<String>
    let isFollowingDefault: Bool
    let defaultDeviceUID: String?
    let deviceSelectionMode: DeviceSelectionMode
    let isMuted: Bool
    let boost: BoostLevel
    let onBoostChange: (BoostLevel) -> Void
    let onVolumeChange: (Float) -> Void
    let onMuteChange: (Bool) -> Void
    let onDeviceSelected: (String) -> Void
    let onDevicesSelected: (Set<String>) -> Void
    let onDeviceModeChange: (DeviceSelectionMode) -> Void
    let onSelectFollowDefault: () -> Void
    let eqSettings: EQSettings
    let userPresets: [UserEQPreset]
    let onEQChange: (EQSettings) -> Void
    let onUserPresetSelected: (UserEQPreset) -> Void
    let onSavePreset: (String, EQSettings) -> Void
    let onDeleteUserPreset: (UUID) -> Void
    let onRenameUserPreset: (UUID, String) -> Void
    let isEQExpanded: Bool
    let onEQToggle: () -> Void
    let sliderWidth: CGFloat
    let isPinned: Bool
    let onTogglePin: () -> Void
    let isReordering: Bool
    let reorderOffset: CGFloat
    let onReorderChanged: (CGFloat) -> Void
    let onReorderEnded: () -> Void
    let isFocused: Bool

    @State private var localEQSettings: EQSettings

    init(
        appInfo: PinnedAppInfo,
        icon: NSImage,
        volume: Float,
        devices: [AudioDevice],
        deviceIconOverrides: [String: String] = [:],
        selectedDeviceUID: String?,
        selectedDeviceUIDs: Set<String> = [],
        isFollowingDefault: Bool = true,
        defaultDeviceUID: String? = nil,
        deviceSelectionMode: DeviceSelectionMode = .single,
        isMuted: Bool = false,
        boost: BoostLevel = .x1,
        onBoostChange: @escaping (BoostLevel) -> Void = { _ in },
        onVolumeChange: @escaping (Float) -> Void,
        onMuteChange: @escaping (Bool) -> Void,
        onDeviceSelected: @escaping (String) -> Void,
        onDevicesSelected: @escaping (Set<String>) -> Void = { _ in },
        onDeviceModeChange: @escaping (DeviceSelectionMode) -> Void = { _ in },
        onSelectFollowDefault: @escaping () -> Void = {},
        eqSettings: EQSettings = EQSettings(),
        userPresets: [UserEQPreset] = [],
        onEQChange: @escaping (EQSettings) -> Void = { _ in },
        onUserPresetSelected: @escaping (UserEQPreset) -> Void = { _ in },
        onSavePreset: @escaping (String, EQSettings) -> Void = { _, _ in },
        onDeleteUserPreset: @escaping (UUID) -> Void = { _ in },
        onRenameUserPreset: @escaping (UUID, String) -> Void = { _, _ in },
        isEQExpanded: Bool = false,
        onEQToggle: @escaping () -> Void = {},
        sliderWidth: CGFloat = DesignTokens.Dimensions.sliderWidth,
        isPinned: Bool = true,
        onTogglePin: @escaping () -> Void,
        isReordering: Bool,
        reorderOffset: CGFloat,
        onReorderChanged: @escaping (CGFloat) -> Void,
        onReorderEnded: @escaping () -> Void,
        isFocused: Bool = false
    ) {
        self.appInfo = appInfo
        self.icon = icon
        self.volume = volume
        self.devices = devices
        self.deviceIconOverrides = deviceIconOverrides
        self.selectedDeviceUID = selectedDeviceUID
        self.selectedDeviceUIDs = selectedDeviceUIDs
        self.isFollowingDefault = isFollowingDefault
        self.defaultDeviceUID = defaultDeviceUID
        self.deviceSelectionMode = deviceSelectionMode
        self.isMuted = isMuted
        self.boost = boost
        self.onBoostChange = onBoostChange
        self.onVolumeChange = onVolumeChange
        self.onMuteChange = onMuteChange
        self.onDeviceSelected = onDeviceSelected
        self.onDevicesSelected = onDevicesSelected
        self.onDeviceModeChange = onDeviceModeChange
        self.onSelectFollowDefault = onSelectFollowDefault
        self.eqSettings = eqSettings
        self.userPresets = userPresets
        self.onEQChange = onEQChange
        self.onUserPresetSelected = onUserPresetSelected
        self.onSavePreset = onSavePreset
        self.onDeleteUserPreset = onDeleteUserPreset
        self.onRenameUserPreset = onRenameUserPreset
        self.isEQExpanded = isEQExpanded
        self.onEQToggle = onEQToggle
        self.sliderWidth = sliderWidth
        self.isPinned = isPinned
        self.onTogglePin = onTogglePin
        self.isReordering = isReordering
        self.reorderOffset = reorderOffset
        self.onReorderChanged = onReorderChanged
        self.onReorderEnded = onReorderEnded
        self.isFocused = isFocused
        self._localEQSettings = State(initialValue: eqSettings)
    }

    var body: some View {
        ExpandableGlassRow(isExpanded: isEQExpanded, isFocused: isFocused) {
            HStack(spacing: DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs) {
                ReorderDragHandle(
                    onChanged: onReorderChanged,
                    onEnded: onReorderEnded
                )

                VUMeter(level: 0, isMuted: isMuted || volume == 0)
                    .opacity(0.6)

                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: DesignTokens.Dimensions.rowContentHeight - 4,
                        height: DesignTokens.Dimensions.rowContentHeight - 4
                    )
                    .opacity(0.65)

                VStack(alignment: .leading, spacing: 1) {
                    Text(appInfo.displayName)
                        .font(DesignTokens.Typography.rowName)
                        .lineLimit(1)
                        .help(appInfo.displayName)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)

                    if let subtitle = DevicePicker.routingSubtitle(
                        devices: devices,
                        selectedDeviceUID: selectedDeviceUID ?? defaultDeviceUID ?? "",
                        selectedDeviceUIDs: selectedDeviceUIDs,
                        isFollowingDefault: isFollowingDefault,
                        mode: deviceSelectionMode
                    ) {
                        subtitle
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                AppRowControls(
                    volume: volume,
                    isMuted: isMuted,
                    devices: devices,
                    deviceIconOverrides: deviceIconOverrides,
                    selectedDeviceUID: selectedDeviceUID ?? defaultDeviceUID ?? "",
                    selectedDeviceUIDs: selectedDeviceUIDs,
                    isFollowingDefault: isFollowingDefault,
                    defaultDeviceUID: defaultDeviceUID,
                    deviceSelectionMode: deviceSelectionMode,
                    boost: boost,
                    sliderWidth: sliderWidth,
                    onVolumeChange: onVolumeChange,
                    onMuteChange: onMuteChange,
                    onBoostChange: onBoostChange,
                    onDeviceSelected: onDeviceSelected,
                    onDevicesSelected: onDevicesSelected,
                    onDeviceModeChange: onDeviceModeChange,
                    onSelectFollowDefault: onSelectFollowDefault,
                    isRowFocused: isFocused
                )

                AppEQButton(isExpanded: isEQExpanded, action: onEQToggle)
                AppPinButton(isPinned: isPinned, action: onTogglePin)
            }
            .frame(height: DesignTokens.Dimensions.rowContentHeight)
            .contentShape(Rectangle())
        } expandedContent: {
            EQPanelView(
                settings: $localEQSettings,
                userPresets: userPresets,
                onPresetSelected: { preset in
                    localEQSettings = preset.settings
                    onEQChange(preset.settings)
                },
                onUserPresetSelected: { userPreset in
                    localEQSettings = userPreset.settings
                    onUserPresetSelected(userPreset)
                },
                onSettingsChanged: onEQChange,
                onSavePreset: onSavePreset,
                onDeleteUserPreset: onDeleteUserPreset,
                onRenameUserPreset: onRenameUserPreset
            )
            .padding(.top, DesignTokens.Spacing.sm)
        }
        .onChange(of: eqSettings) { _, newValue in
            localEQSettings = newValue
        }
        .continuousReorderAppearance(
            isDragging: isReordering,
            offset: reorderOffset
        )
    }
}
