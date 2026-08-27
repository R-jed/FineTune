// FineTune/Views/Rows/AppRowControls.swift
import SwiftUI

/// Shared controls for app rows: mute button, volume slider, percentage, VU meter, device picker, EQ, and pin.
/// Used by both AppRow (active apps) and InactiveAppRow (pinned inactive apps).
struct AppRowControls: View {
    let volume: Float
    let isMuted: Bool
    let devices: [AudioDevice]
    var deviceIconOverrides: [String: String] = [:]
    let selectedDeviceUID: String
    let selectedDeviceUIDs: Set<String>
    let isFollowingDefault: Bool
    let defaultDeviceUID: String?
    let deviceSelectionMode: DeviceSelectionMode
    let boost: BoostLevel
    let isEQExpanded: Bool
    var sliderWidth: CGFloat = DesignTokens.Dimensions.sliderWidth
    var volumeAccessibilityLabel: Text = Text("App volume")
    let onVolumeChange: (Float) -> Void
    let onMuteChange: (Bool) -> Void
    let onBoostChange: (BoostLevel) -> Void
    let onDeviceSelected: (String) -> Void
    let onDevicesSelected: (Set<String>) -> Void
    let onDeviceModeChange: (DeviceSelectionMode) -> Void
    let onSelectFollowDefault: () -> Void
    let onEQToggle: () -> Void
    var isPinned: Bool = false
    var onTogglePin: () -> Void = {}
    var isRowFocused: Bool = false

    @State private var dragOverrideValue: Double?
    @State private var isEQButtonHovered = false
    @State private var isPinButtonHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var storedSliderFraction: Double {
        VolumeMapping.gainToSlider(volume)
    }

    /// During direct manipulation, the local drag value is the user's current intent.
    /// Treat a drag as locally unmuted while the backend catches up so the slider
    /// stays under the pointer instead of snapping back to visual zero.
    private var presentationState: VolumePresentationState {
        VolumePresentationState(
            storedFraction: dragOverrideValue ?? storedSliderFraction,
            isMuted: dragOverrideValue == nil ? isMuted : false,
            sourceIsActive: false
        )
    }

    private var sliderValue: Double {
        presentationState.displayFraction
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { sliderValue },
            set: { newValue in
                let plan = presentationState.planAdjustment(to: newValue)
                dragOverrideValue = plan.fraction
                onVolumeChange(VolumeMapping.sliderToGain(plan.fraction))
                if plan.shouldUnmute {
                    onMuteChange(false)
                }
            }
        )
    }

    private var displayedPercentage: Int {
        presentationState.displayPercent
    }

    private var showMutedIcon: Bool {
        presentationState.displaysMuted
    }

    private var eqButtonColor: Color {
        if isEQExpanded {
            return DesignTokens.Colors.interactiveActive
        } else if isEQButtonHovered {
            return DesignTokens.Colors.interactiveHover
        } else {
            return DesignTokens.Colors.interactiveDefault
        }
    }

    private var pinButtonColor: Color {
        if isPinned {
            return DesignTokens.Colors.interactiveActive
        } else if isPinButtonHovered {
            return DesignTokens.Colors.interactiveHover
        } else {
            return DesignTokens.Colors.interactiveDefault
        }
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            MuteButton(isMuted: showMutedIcon, levelFraction: sliderValue) {
                if showMutedIcon {
                    let restoredFraction = presentationState.unmuteFraction()
                    if restoredFraction != storedSliderFraction {
                        onVolumeChange(VolumeMapping.sliderToGain(restoredFraction))
                    }
                    onMuteChange(false)
                } else {
                    onMuteChange(true)
                }
            }

            LiquidGlassSlider(
                value: sliderBinding,
                showUnityMarker: false,
                onEditingChanged: { editing in
                    if !editing {
                        dragOverrideValue = nil
                    }
                },
                accessibilityLabel: volumeAccessibilityLabel
            )
            .frame(width: sliderWidth)
            .scrollWheelStep(
                sliderBinding,
                in: 0.0...1.0,
                requiresOptionModifier: true
            )

            EditablePercentage(
                percentage: Binding(
                    get: { displayedPercentage },
                    set: { newPercentage in
                        let plan = presentationState.planAdjustment(
                            to: Double(newPercentage) / 100.0
                        )
                        onVolumeChange(VolumeMapping.sliderToGain(plan.fraction))
                        if plan.shouldUnmute {
                            onMuteChange(false)
                        }
                    }
                ),
                range: 0...100,
                isRowFocused: isRowFocused
            )

            BoostChevrons(level: boost, onTap: { onBoostChange(boost.next) })

            DevicePicker(
                devices: devices,
                deviceIconOverrides: deviceIconOverrides,
                selectedDeviceUID: selectedDeviceUID,
                selectedDeviceUIDs: selectedDeviceUIDs,
                isFollowingDefault: isFollowingDefault,
                defaultDeviceUID: defaultDeviceUID,
                mode: deviceSelectionMode,
                onModeChange: onDeviceModeChange,
                onDeviceSelected: onDeviceSelected,
                onDevicesSelected: onDevicesSelected,
                onSelectFollowDefault: onSelectFollowDefault,
                showModeToggle: true,
                triggerWidth: 0,
                triggerStyle: .iconOnly
            )

            Button {
                onEQToggle()
            } label: {
                ZStack {
                    Image(systemName: "slider.vertical.3")
                        .opacity(isEQExpanded ? 0 : 1)

                    Image(systemName: "xmark")
                        .opacity(isEQExpanded ? 1 : 0)
                }
                .font(.system(size: 12))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(eqButtonColor)
                .frame(
                    minWidth: DesignTokens.Dimensions.minTouchTarget,
                    minHeight: DesignTokens.Dimensions.minTouchTarget
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isEQExpanded ? "Close Equalizer" : "Equalizer")
            .onHover { isEQButtonHovered = $0 }
            .help(isEQExpanded ? "Close Equalizer" : "Equalizer")
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isEQExpanded)
            .animation(reduceMotion ? nil : DesignTokens.Animation.hover, value: isEQButtonHovered)

            Button(action: onTogglePin) {
                Image(systemName: isPinned ? "pin.fill" : "pin.slash")
                    .font(.system(size: 12))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(pinButtonColor)
                    .frame(
                        minWidth: DesignTokens.Dimensions.minTouchTarget,
                        minHeight: DesignTokens.Dimensions.minTouchTarget
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPinned ? "Unpin app" : "Pin app")
            .onHover { isPinButtonHovered = $0 }
            .help(isPinned ? "Unpin app" : "Pin app")
            .animation(reduceMotion ? nil : DesignTokens.Animation.hover, value: isPinButtonHovered)
        }
        .fixedSize()
    }
}
