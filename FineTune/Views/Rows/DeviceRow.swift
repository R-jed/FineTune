// FineTune/Views/Rows/DeviceRow.swift
import SwiftUI

/// A row displaying a device with volume controls.
/// Used in the Output Devices section.
///
/// Volume mapping depends on the device's `volumeBackend`:
/// - **Hardware**: Identity mapping (slider == HAL scalar). CoreAudio's VirtualMainVolume
///   scalar is already audio-tapered by the driver — IOAudioLevelControl applies a dB curve
///   by default (see `setLinearScale()` in IOAudioLevelControl.h). Empirically confirmed:
///   scalar 0.50 → −50 dB, scalar 0.10 → −90 dB (100 dB range, linear-in-dB).
/// - **DDC**: Identity mapping (slider == DDC 0–100 / 100). DDC writes VCP 0x62 (Audio
///   Speaker Volume) as an integer 0–100 directly to the monitor via I2C, bypassing the HAL
///   entirely. The monitor's firmware handles perceptual mapping internally. Identity matches
///   the OSD values users see on the physical display. MonitorControl uses the same approach.
/// - **Software**: VolumeMapping x² curve. Software gain is a linear PCM amplitude multiplier
///   that needs perceptual scaling (dr-lex.be, Discord perceptual).
///
/// See: IOAudioLevelControl.h, MCCS VCP 0x62, empirical ScalarToDecibels measurement.
struct DeviceRow: View {
    let device: AudioDevice
    let isDefault: Bool
    let volume: Float
    let isMuted: Bool
    /// The device's volume backend. Determines which slider ↔ value mapping to use.
    let volumeBackend: VolumeControlTier
    let onSetDefault: () -> Void
    /// Applies the complete normalized output command through the backend owner.
    let onVolumeCommand: (OutputVolumeCommandPlan) -> Void

    // AutoEQ (all optional — existing call sites work without them)
    let autoEQProfileName: String?
    let autoEQEnabled: Bool
    let onAutoEQToggle: ((Bool) -> Void)?
    let autoEQProfileManager: AutoEQProfileManager?
    let autoEQSelection: AutoEQSelection?
    let autoEQFavoriteIDs: Set<String>
    let onAutoEQSelect: ((AutoEQProfile?) -> Void)?
    let onAutoEQImport: (() -> Void)?
    let onAutoEQToggleFavorite: ((String) -> Void)?
    let autoEQImportError: LocalizedStringResource?
    let autoEQPreampEnabled: Bool
    let onAutoEQPreampToggle: (() -> Void)?
    let isFocused: Bool
    let iconOverrideSymbol: String?

    @State private var sliderValue: Double
    @State private var interactionOverrideValue: Double?
    @State private var isEditing = false

    private var presentationState: VolumePresentationState {
        VolumePresentationState(
            storedFraction: interactionOverrideValue ?? sliderValue,
            isMuted: interactionOverrideValue == nil ? isMuted : false,
            sourceIsActive: false
        )
    }

    private var displayedPercentage: Int {
        presentationState.displayPercent
    }

    private var showMutedIcon: Bool {
        presentationState.displaysMuted
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { presentationState.displayFraction },
            set: { newValue in
                applyUserVolume(newValue)
            }
        )
    }

    #if DEBUG
    var displayedPercentageForTest: Int { displayedPercentage }
    var showMutedIconForTest: Bool { showMutedIcon }
    #endif

    private var displayIcon: NSImage? {
        DeviceIconResolver.displayIcon(
            overrideSymbol: iconOverrideSymbol,
            automatic: device.icon,
            deviceName: device.name
        )
    }

    init(
        device: AudioDevice,
        isDefault: Bool,
        volume: Float,
        isMuted: Bool,
        volumeBackend: VolumeControlTier = .hardware,
        onSetDefault: @escaping () -> Void,
        onVolumeCommand: @escaping (OutputVolumeCommandPlan) -> Void,
        autoEQProfileName: String? = nil,
        autoEQEnabled: Bool = false,
        onAutoEQToggle: ((Bool) -> Void)? = nil,
        autoEQProfileManager: AutoEQProfileManager? = nil,
        autoEQSelection: AutoEQSelection? = nil,
        autoEQFavoriteIDs: Set<String> = [],
        onAutoEQSelect: ((AutoEQProfile?) -> Void)? = nil,
        onAutoEQImport: (() -> Void)? = nil,
        onAutoEQToggleFavorite: ((String) -> Void)? = nil,
        autoEQImportError: LocalizedStringResource? = nil,
        autoEQPreampEnabled: Bool = true,
        onAutoEQPreampToggle: (() -> Void)? = nil,
        isFocused: Bool = false,
        iconOverrideSymbol: String? = nil
    ) {
        self.device = device
        self.isDefault = isDefault
        self.volume = volume
        self.isMuted = isMuted
        self.volumeBackend = volumeBackend
        self.onSetDefault = onSetDefault
        self.onVolumeCommand = onVolumeCommand
        self.autoEQProfileName = autoEQProfileName
        self.autoEQEnabled = autoEQEnabled
        self.onAutoEQToggle = onAutoEQToggle
        self.autoEQProfileManager = autoEQProfileManager
        self.autoEQSelection = autoEQSelection
        self.autoEQFavoriteIDs = autoEQFavoriteIDs
        self.onAutoEQSelect = onAutoEQSelect
        self.onAutoEQImport = onAutoEQImport
        self.onAutoEQToggleFavorite = onAutoEQToggleFavorite
        self.autoEQImportError = autoEQImportError
        self.autoEQPreampEnabled = autoEQPreampEnabled
        self.onAutoEQPreampToggle = onAutoEQPreampToggle
        self.isFocused = isFocused
        self.iconOverrideSymbol = iconOverrideSymbol
        self._sliderValue = State(initialValue: Self.volumeToSlider(volume, backend: volumeBackend))
    }

    var body: some View {
        deviceHeader
            .contentShape(Rectangle())
            .onTapGesture {
                if !isDefault {
                    onSetDefault()
                }
            }
            .hoverableRow(isFocused: isFocused)
    }

    private var deviceHeader: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            DeviceBadge(icon: displayIcon, isSelected: isDefault)

            HStack(spacing: DesignTokens.Spacing.xs) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(device.name)
                        .font(isDefault ? DesignTokens.Typography.rowNameBold : DesignTokens.Typography.rowName)
                        .lineLimit(1)
                        .help(Text(verbatim: device.name))
                        .accessibilityValue(isDefault ? Text("Default device") : Text("Set as default"))
                        .accessibilityAction {
                            if !isDefault {
                                onSetDefault()
                            }
                        }

                    if let profileName = autoEQProfileName {
                        autoEQSubtitle(profileName: profileName)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                            .lineLimit(1)
                            .help(Text(verbatim: profileName))
                    }
                }

                Spacer(minLength: 0)

                if device.supportsAutoEQ,
                   let profileManager = autoEQProfileManager,
                   let onSelect = onAutoEQSelect,
                   let onImport = onAutoEQImport {
                    AutoEQPicker(
                        profileManager: profileManager,
                        profileName: autoEQProfileName,
                        selection: autoEQSelection,
                        favoriteIDs: autoEQFavoriteIDs,
                        onSelect: onSelect,
                        onImport: onImport,
                        onToggleFavorite: { id in onAutoEQToggleFavorite?(id) },
                        importError: autoEQImportError,
                        isCorrectionEnabled: autoEQEnabled,
                        onCorrectionToggle: onAutoEQToggle,
                        preampEnabled: autoEQPreampEnabled,
                        onPreampToggle: onAutoEQPreampToggle
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            MuteButton(isMuted: showMutedIcon, levelFraction: presentationState.displayFraction) {
                let plan = OutputVolumeCommandPlan.muteToggle(
                    currentFraction: presentationState.storedFraction,
                    isMuted: isMuted,
                    tier: volumeBackend
                )
                if plan.fraction != sliderValue {
                    interactionOverrideValue = plan.fraction
                    sliderValue = plan.fraction
                }
                onVolumeCommand(plan)
            }

            LiquidGlassSlider(
                value: sliderBinding,
                onEditingChanged: { editing in
                    isEditing = editing
                    if !editing {
                        interactionOverrideValue = nil
                    }
                },
                accessibilityLabel: Text("Volume") + Text(verbatim: ": \(device.name)")
            )

            EditablePercentage(
                percentage: Binding(
                    get: { displayedPercentage },
                    set: { newPercentage in
                        applyUserVolume(Double(newPercentage) / 100.0)
                    }
                ),
                range: 0...100,
                isRowFocused: isFocused
            )
        }
        .frame(height: DesignTokens.Dimensions.rowContentHeight)
        .onChange(of: volume) { _, newValue in
            guard !isEditing else { return }
            let newSlider = Self.volumeToSlider(newValue, backend: volumeBackend)
            guard newSlider != sliderValue else {
                interactionOverrideValue = nil
                return
            }
            sliderValue = newSlider
            interactionOverrideValue = nil
        }
        .onChange(of: isMuted) { _, _ in
            interactionOverrideValue = nil
        }
    }

    private func applyUserVolume(_ requestedFraction: Double) {
        let plan = OutputVolumeCommandPlan.adjustment(
            currentFraction: presentationState.storedFraction,
            isMuted: isMuted,
            tier: volumeBackend,
            requestedFraction: requestedFraction
        )
        interactionOverrideValue = plan.fraction
        sliderValue = plan.fraction
        onVolumeCommand(plan)
    }

    private func autoEQSubtitle(profileName: String) -> Text {
        let profile = Text(verbatim: profileName)
        return autoEQEnabled ? profile : profile + Text(" (off)")
    }
}

extension DeviceRow {
    static func volumeToSlider(_ volume: Float, backend: VolumeControlTier) -> Double {
        VolumeMapping.sliderFraction(forSystemGain: volume, tier: backend)
    }
}

#Preview("Device Row - Default") {
    PreviewContainer {
        VStack(spacing: 0) {
            DeviceRow(
                device: MockData.sampleDevices[0],
                isDefault: true,
                volume: 0.75,
                isMuted: false,
                onSetDefault: {},
                onVolumeCommand: { _ in }
            )

            DeviceRow(
                device: MockData.sampleDevices[1],
                isDefault: false,
                volume: 1.0,
                isMuted: false,
                onSetDefault: {},
                onVolumeCommand: { _ in }
            )

            DeviceRow(
                device: MockData.sampleDevices[2],
                isDefault: false,
                volume: 0.5,
                isMuted: true,
                onSetDefault: {},
                onVolumeCommand: { _ in }
            )
        }
    }
}
