// FineTune/Models/AudioPresentationState.swift

/// Pure result for a user-originated volume change.
struct VolumeAdjustmentPlan: Equatable {
    let fraction: Double
    let shouldUnmute: Bool
}

/// Pure result for activating the visible mute control.
struct VolumeMuteTogglePlan: Equatable {
    let fraction: Double
    let muted: Bool
}

/// Pure per-App command plan. App gain always uses the shared squared display
/// mapping, and any unmute happens after the target gain is installed so the tap
/// cannot briefly reopen at the previous gain.
struct AppVolumeCommandPlan: Equatable {
    let fraction: Double
    let gain: Float
    let muted: Bool
    let shouldWriteVolume: Bool
    let shouldWriteMute: Bool

    static func adjustment(
        currentFraction: Double,
        isMuted: Bool,
        requestedFraction: Double
    ) -> Self {
        let adjustment = VolumePresentationState(
            storedFraction: currentFraction,
            isMuted: isMuted,
            sourceIsActive: false
        ).planAdjustment(to: requestedFraction)
        return Self(
            fraction: adjustment.fraction,
            gain: VolumeMapping.sliderToGain(adjustment.fraction),
            muted: adjustment.shouldUnmute ? false : isMuted,
            shouldWriteVolume: true,
            shouldWriteMute: adjustment.shouldUnmute
        )
    }

    static func step(currentGain: Float, isMuted: Bool, delta: Double) -> Self {
        let currentFraction = VolumeMapping.gainToSlider(currentGain)
        return adjustment(
            currentFraction: currentFraction,
            isMuted: isMuted,
            requestedFraction: currentFraction + delta
        )
    }

    static func muteToggle(currentGain: Float, isMuted: Bool) -> Self {
        let currentFraction = VolumeMapping.gainToSlider(currentGain)
        let toggle = VolumePresentationState(
            storedFraction: currentFraction,
            isMuted: isMuted,
            sourceIsActive: false
        ).planMuteToggle()
        return Self(
            fraction: toggle.fraction,
            gain: VolumeMapping.sliderToGain(toggle.fraction),
            muted: toggle.muted,
            shouldWriteVolume: toggle.fraction != currentFraction,
            shouldWriteMute: toggle.muted != isMuted
        )
    }

    func apply(setVolume: (Float) -> Void, setMute: (Bool) -> Void) {
        if shouldWriteVolume { setVolume(gain) }
        if shouldWriteMute { setMute(muted) }
    }
}

/// Pure user-visible volume state. The backend keeps owning the stored volume and mute flag;
/// this type only derives what FineTune should present to the user.
struct VolumePresentationState: Equatable {
    static let fallbackUnmuteFraction = 0.5

    let storedFraction: Double
    let isMuted: Bool
    let sourceIsActive: Bool

    init(storedFraction: Double, isMuted: Bool, sourceIsActive: Bool) {
        self.storedFraction = Self.clamp(storedFraction)
        self.isMuted = isMuted
        self.sourceIsActive = sourceIsActive
    }

    /// Slider value shown to the user. Explicit mute always presents zero.
    /// Fractions that round to 0% are normalized to visual zero so icon, slider,
    /// and percentage cannot contradict one another.
    var displayFraction: Double {
        guard !isMuted, storedPercent > 0 else { return 0 }
        return storedFraction
    }

    var displayPercent: Int {
        Int((displayFraction * 100).rounded())
    }

    var displaysMuted: Bool {
        isMuted || storedPercent == 0
    }

    var hasAudibleOutput: Bool {
        !displaysMuted
    }

    /// Source activity is intentionally independent from effective output. A muted
    /// app may keep showing source activity so users can tell that it is still playing.
    var sourceActivityVisible: Bool {
        sourceIsActive
    }

    /// Normalize one user-originated volume change and state whether it should clear
    /// an explicit mute. Every volume surface uses the same rule: values above the
    /// visible 0% threshold unmute; zero stays muted.
    func planAdjustment(to requestedFraction: Double) -> VolumeAdjustmentPlan {
        let fraction = Self.clamp(requestedFraction)
        return VolumeAdjustmentPlan(
            fraction: fraction,
            shouldUnmute: isMuted && Self.percent(fraction) > 0
        )
    }

    /// Value to restore when the user explicitly unmutes a zero-output state.
    /// Prefer the backend's still-stored non-zero value, then any remembered value,
    /// and finally the shared 50% fallback.
    func unmuteFraction(rememberedNonZeroFraction: Double? = nil) -> Double {
        if storedPercent > 0 {
            return storedFraction
        }

        if let rememberedNonZeroFraction {
            let remembered = Self.clamp(rememberedNonZeroFraction)
            if Self.percent(remembered) > 0 {
                return remembered
            }
        }

        return Self.fallbackUnmuteFraction
    }

    /// Normalize one explicit mute-control activation. A muted-equivalent zero state
    /// is treated as an unmute request and restores the shared fallback when needed.
    func planMuteToggle(rememberedNonZeroFraction: Double? = nil) -> VolumeMuteTogglePlan {
        if displaysMuted {
            return VolumeMuteTogglePlan(
                fraction: unmuteFraction(rememberedNonZeroFraction: rememberedNonZeroFraction),
                muted: false
            )
        }

        return VolumeMuteTogglePlan(fraction: storedFraction, muted: true)
    }

    private var storedPercent: Int {
        Self.percent(storedFraction)
    }

    private static func clamp(_ value: Double) -> Double {
        max(0, min(1, value))
    }

    private static func percent(_ fraction: Double) -> Int {
        Int((clamp(fraction) * 100).rounded())
    }
}

/// Pure grouping semantics for whether an app belongs in the primary list.
enum AppPresenceGroup: Equatable {
    case pinned
    case normal
    case hidden
    case absent

    static func resolve(isRunning: Bool, isPinned: Bool, isHidden: Bool) -> Self {
        if isHidden { return .hidden }
        if isPinned { return .pinned }
        if isRunning { return .normal }
        return .absent
    }
}
