// FineTune/Views/Rows/AppRowControls.swift
import SwiftUI

/// Shared volume/routing control cluster for app rows. EQ and pin actions live
/// outside this cluster so the parent row can enforce their visual order.
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
    var sliderWidth: CGFloat = DesignTokens.Dimensions.sliderWidth
    var volumeAccessibilityLabel: Text = Text("App volume")
    let onVolumeChange: (Float) -> Void
    let onMuteChange: (Bool) -> Void
    let onBoostChange: (BoostLevel) -> Void
    let onDeviceSelected: (String) -> Void
    let onDevicesSelected: (Set<String>) -> Void
    let onDeviceModeChange: (DeviceSelectionMode) -> Void
    let onSelectFollowDefault: () -> Void
    var isRowFocused: Bool = false

    @State private var interactionOverrideValue: Double?
    @State private var isEditing = false

    private var storedSliderFraction: Double {
        VolumeMapping.gainToSlider(volume)
    }

    /// During direct manipulation, the local interaction value is the user's current intent.
    /// Treat it as locally unmuted while the backend catches up so the slider
    /// stays under the pointer instead of snapping back to visual zero.
    private var presentationState: VolumePresentationState {
        VolumePresentationState(
            storedFraction: interactionOverrideValue ?? storedSliderFraction,
            isMuted: interactionOverrideValue == nil ? isMuted : false,
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
                let state = presentationState
                let plan = AppVolumeCommandPlan.adjustment(
                    currentFraction: state.storedFraction,
                    isMuted: state.isMuted,
                    requestedFraction: newValue
                )
                interactionOverrideValue = plan.fraction
                plan.apply(setVolume: onVolumeChange, setMute: onMuteChange)
            }
        )
    }

    private var displayedPercentage: Int {
        presentationState.displayPercent
    }

    private var showMutedIcon: Bool {
        presentationState.displaysMuted
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            MuteButton(isMuted: showMutedIcon, levelFraction: sliderValue) {
                AppVolumeCommandPlan.muteToggle(
                    currentGain: volume,
                    isMuted: isMuted
                ).apply(setVolume: onVolumeChange, setMute: onMuteChange)
            }

            LiquidGlassSlider(
                value: sliderBinding,
                showUnityMarker: false,
                onEditingChanged: { editing in
                    isEditing = editing
                    if !editing {
                        interactionOverrideValue = nil
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
                        let state = presentationState
                        let plan = AppVolumeCommandPlan.adjustment(
                            currentFraction: state.storedFraction,
                            isMuted: state.isMuted,
                            requestedFraction: Double(newPercentage) / 100.0
                        )
                        plan.apply(setVolume: onVolumeChange, setMute: onMuteChange)
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

        }
        .onChange(of: volume) { _, _ in
            // Direct slider manipulation may keep a local optimistic value until
            // the drag finishes. Wheel/typed changes are not drag sessions, so an
            // external value update must immediately return presentation ownership
            // to the backend instead of leaving a stale override in place.
            guard !isEditing else { return }
            interactionOverrideValue = nil
        }
        .onChange(of: isMuted) { _, _ in
            interactionOverrideValue = nil
        }
    }
}


/// Dedicated EQ action so row layout can place it independently from the
/// volume/routing control cluster.
struct AppEQButton: View {
    let isExpanded: Bool
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var foregroundColor: Color {
        if isExpanded { return DesignTokens.Colors.interactiveActive }
        if isHovered { return DesignTokens.Colors.interactiveHover }
        return DesignTokens.Colors.interactiveDefault
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(systemName: "slider.vertical.3")
                    .opacity(isExpanded ? 0 : 1)
                Image(systemName: "xmark")
                    .opacity(isExpanded ? 1 : 0)
            }
            .font(.system(size: 12))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(foregroundColor)
            .frame(
                minWidth: DesignTokens.Dimensions.minTouchTarget,
                minHeight: DesignTokens.Dimensions.minTouchTarget
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Close Equalizer" : "Equalizer")
        .onHover { isHovered = $0 }
        .help(isExpanded ? "Close Equalizer" : "Equalizer")
        .animation(reduceMotion ? nil : DesignTokens.Animation.hover, value: isHovered)
    }
}

struct AppPinButton: View {
    let isPinned: Bool
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var foregroundColor: Color {
        if isPinned { return DesignTokens.Colors.interactiveActive }
        if isHovered { return DesignTokens.Colors.interactiveHover }
        return DesignTokens.Colors.interactiveDefault
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: isPinned ? "pin.slash.fill" : "pin")
                .font(.system(size: 12))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(foregroundColor)
                .frame(
                    minWidth: DesignTokens.Dimensions.minTouchTarget,
                    minHeight: DesignTokens.Dimensions.minTouchTarget
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPinned ? "Unpin app" : "Pin app")
        .onHover { isHovered = $0 }
        .help(isPinned ? "Unpin app" : "Pin app")
        .animation(reduceMotion ? nil : DesignTokens.Animation.hover, value: isHovered)
    }
}
