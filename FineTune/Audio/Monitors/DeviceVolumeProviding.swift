import Foundation
import AudioToolbox

enum VolumeControlTier: String, Codable, Equatable {
    case hardware
    case ddc
    case software

    var displayName: LocalizedStringResource {
        switch self {
        case .hardware: "Hardware"
        case .ddc: "DDC"
        case .software: "Software"
        }
    }
}

enum OutputVolumeWriteOrder: Equatable {
    case volumeThenMute
    case muteThenVolume
}

/// Backend-aware mutation plan for output-device volume commands.
/// DDC unmute restores its saved volume, so muted DDC adjustments must unmute
/// before writing the requested target. Software does the inverse so unmute
/// cannot restore an older saved value over a fresh user adjustment.
struct OutputVolumeCommandPlan: Equatable {
    let fraction: Double
    let gain: Float
    let muted: Bool
    let shouldWriteVolume: Bool
    let shouldWriteMute: Bool
    let writeOrder: OutputVolumeWriteOrder

    static func adjustment(
        currentFraction: Double,
        isMuted: Bool,
        tier: VolumeControlTier,
        requestedFraction: Double
    ) -> Self {
        let adjustment = VolumePresentationState(
            storedFraction: currentFraction,
            isMuted: isMuted,
            sourceIsActive: false
        ).planAdjustment(to: requestedFraction)
        let targetMuted = adjustment.shouldUnmute ? false : isMuted
        let order: OutputVolumeWriteOrder =
            isMuted && !targetMuted && tier == .ddc
                ? .muteThenVolume
                : .volumeThenMute

        return Self(
            fraction: adjustment.fraction,
            gain: VolumeMapping.systemGain(forSliderFraction: adjustment.fraction, tier: tier),
            muted: targetMuted,
            shouldWriteVolume: true,
            shouldWriteMute: targetMuted != isMuted,
            writeOrder: order
        )
    }

    static func step(
        currentGain: Float,
        isMuted: Bool,
        tier: VolumeControlTier,
        delta: Double
    ) -> Self {
        let currentFraction = VolumeMapping.sliderFraction(
            forSystemGain: currentGain,
            tier: tier
        )
        return adjustment(
            currentFraction: currentFraction,
            isMuted: isMuted,
            tier: tier,
            requestedFraction: currentFraction + delta
        )
    }

    static func muteToggle(
        currentFraction: Double,
        isMuted: Bool,
        tier: VolumeControlTier
    ) -> Self {
        let toggle = VolumePresentationState(
            storedFraction: currentFraction,
            isMuted: isMuted,
            sourceIsActive: false
        ).planMuteToggle()
        let order: OutputVolumeWriteOrder =
            isMuted && !toggle.muted && tier == .ddc
                ? .muteThenVolume
                : .volumeThenMute
        return Self(
            fraction: toggle.fraction,
            gain: VolumeMapping.systemGain(forSliderFraction: toggle.fraction, tier: tier),
            muted: toggle.muted,
            shouldWriteVolume: !toggle.muted && toggle.fraction != currentFraction,
            shouldWriteMute: toggle.muted != isMuted,
            writeOrder: order
        )
    }

    func apply(setVolume: (Float) -> Void, setMute: (Bool) -> Void) {
        switch writeOrder {
        case .volumeThenMute:
            if shouldWriteVolume { setVolume(gain) }
            if shouldWriteMute { setMute(muted) }
        case .muteThenVolume:
            if shouldWriteMute { setMute(muted) }
            if shouldWriteVolume { setVolume(gain) }
        }
    }
}

@MainActor
protocol DeviceVolumeProviding: AnyObject {
    var defaultDeviceID: AudioDeviceID { get }
    var defaultDeviceUID: String? { get }
    var defaultInputDeviceUID: String? { get }
    var volumes: [AudioDeviceID: Float] { get }
    var muteStates: [AudioDeviceID: Bool] { get }

    var onVolumeChanged: ((AudioDeviceID, Float) -> Void)? { get set }
    var onMuteChanged: ((AudioDeviceID, Bool) -> Void)? { get set }
    var onDefaultDeviceChanged: ((String) -> Void)? { get set }
    var onDefaultInputDeviceChanged: ((String) -> Void)? { get set }

    @discardableResult
    func setDefaultDevice(_ deviceID: AudioDeviceID) -> Bool
    @discardableResult
    func setDefaultInputDevice(_ deviceID: AudioDeviceID) -> Bool

    /// Writes a volume scalar through whichever backend this device uses.
    func setVolume(for deviceID: AudioDeviceID, to volume: Float)

    /// Writes a mute state through whichever backend this device uses.
    func setMute(for deviceID: AudioDeviceID, to muted: Bool)

    /// Applies one normalized user command with backend-specific mutation order.
    func applyOutputCommand(_ command: OutputVolumeCommandPlan, for deviceID: AudioDeviceID)

    /// Returns the non-presentation output volume that user adjustments should
    /// continue from. Software and DDC mute store their pre-mute values separately
    /// while exposing zero through their backend, so callers must not treat that
    /// visible zero as the user's stored volume.
    func storedOutputVolume(for deviceID: AudioDeviceID) -> Float

    func outputVolumeBackend(for deviceID: AudioDeviceID) -> VolumeControlTier

    /// Returns the tier that auto-detection would pick, ignoring any saved override.
    /// Used by the device detail sheet to display the "Auto: <tier>" badge.
    func autoDetectedOutputVolumeBackend(for deviceID: AudioDeviceID) -> VolumeControlTier

    func outputProcessingGain(for deviceID: AudioDeviceID) -> Float
    func refreshOutputDeviceStates()

    /// Refreshes a single device's volume/mute state after a tier override
    /// change (manual via detail sheet or auto-promotion on write-failure).
    func applyTierOverrideChange(for deviceID: AudioDeviceID)

    func start()
    func stop()

    /// Called after DDC probe completes to refresh volume/mute states.
    /// Default implementation is a no-op (only relevant for DDC-capable monitors).
    func refreshAfterDDCProbe()
}

extension DeviceVolumeProviding {
    func storedOutputVolume(for deviceID: AudioDeviceID) -> Float {
        volumes[deviceID] ?? 0
    }

    func toggleUserOutputMute(for deviceID: AudioDeviceID) {
        let tier = outputVolumeBackend(for: deviceID)
        let currentFraction = VolumeMapping.sliderFraction(
            forSystemGain: storedOutputVolume(for: deviceID),
            tier: tier
        )
        let command = OutputVolumeCommandPlan.muteToggle(
            currentFraction: currentFraction,
            isMuted: muteStates[deviceID] ?? false,
            tier: tier
        )
        applyOutputCommand(command, for: deviceID)
    }

    func outputProcessingGain(for deviceID: AudioDeviceID) -> Float {
        1.0
    }

    func refreshOutputDeviceStates() {}

    func applyTierOverrideChange(for deviceID: AudioDeviceID) {}

    func autoDetectedOutputVolumeBackend(for deviceID: AudioDeviceID) -> VolumeControlTier {
        outputVolumeBackend(for: deviceID)
    }

    func refreshAfterDDCProbe() {}
}
