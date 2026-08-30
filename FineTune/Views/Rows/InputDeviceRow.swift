// FineTune/Views/Rows/InputDeviceRow.swift
import SwiftUI

/// A row displaying an input device (microphone) with volume controls.
/// Used in the Input Devices section.
struct InputDeviceRow: View {
    let device: AudioDevice
    let isDefault: Bool
    let volume: Float
    let isMuted: Bool
    let onSetDefault: () -> Void
    let onUserVolumeChange: (Float) -> Void
    let onUserMuteToggle: () -> Void
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
        onSetDefault: @escaping () -> Void,
        onUserVolumeChange: @escaping (Float) -> Void,
        onUserMuteToggle: @escaping () -> Void,
        isFocused: Bool = false,
        iconOverrideSymbol: String? = nil
    ) {
        self.device = device
        self.isDefault = isDefault
        self.volume = volume
        self.isMuted = isMuted
        self.onSetDefault = onSetDefault
        self.onUserVolumeChange = onUserVolumeChange
        self.onUserMuteToggle = onUserMuteToggle
        self.isFocused = isFocused
        self.iconOverrideSymbol = iconOverrideSymbol
        self._sliderValue = State(initialValue: Double(max(0, min(1, volume))))
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
            .onChange(of: volume) { _, newValue in
                guard !isEditing else { return }
                let newSlider = Double(max(0, min(1, newValue)))
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

    private var deviceHeader: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            DeviceBadge(icon: displayIcon, isSelected: isDefault, fallbackSymbol: "mic")

            Text(device.name)
                .font(isDefault ? DesignTokens.Typography.rowNameBold : DesignTokens.Typography.rowName)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(Text(verbatim: device.name))
                .accessibilityValue(isDefault ? Text("Default device") : Text("Set as default"))
                .accessibilityAction {
                    if !isDefault {
                        onSetDefault()
                    }
                }

            InputMuteButton(isMuted: showMutedIcon) {
                let plan = presentationState.planMuteToggle()
                if plan.fraction != sliderValue {
                    interactionOverrideValue = plan.fraction
                    sliderValue = plan.fraction
                }
                onUserMuteToggle()
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
    }

    private func applyUserVolume(_ requestedFraction: Double) {
        let plan = presentationState.planAdjustment(to: requestedFraction)
        interactionOverrideValue = plan.fraction
        sliderValue = plan.fraction
        onUserVolumeChange(Float(plan.fraction))
    }
}

#Preview("Input Device Row - Default") {
    PreviewContainer {
        VStack(spacing: 0) {
            InputDeviceRow(
                device: AudioDevice(
                    id: 1,
                    uid: "built-in-mic",
                    name: "MacBook Pro Microphone",
                    icon: nil,
                    supportsAutoEQ: false
                ),
                isDefault: true,
                volume: 0.75,
                isMuted: false,
                onSetDefault: {},
                onUserVolumeChange: { _ in },
                onUserMuteToggle: {}
            )

            InputDeviceRow(
                device: AudioDevice(
                    id: 2,
                    uid: "usb-mic",
                    name: "Blue Yeti",
                    icon: nil,
                    supportsAutoEQ: false
                ),
                isDefault: false,
                volume: 1.0,
                isMuted: false,
                onSetDefault: {},
                onUserVolumeChange: { _ in },
                onUserMuteToggle: {}
            )

            InputDeviceRow(
                device: AudioDevice(
                    id: 3,
                    uid: "airpods-mic",
                    name: "AirPods Pro",
                    icon: nil,
                    supportsAutoEQ: false
                ),
                isDefault: false,
                volume: 0.5,
                isMuted: true,
                onSetDefault: {},
                onUserVolumeChange: { _ in },
                onUserMuteToggle: {}
            )
        }
    }
}
