// FineTune/Models/AudioPresentationState.swift

/// Pure result for a user-originated volume change.
struct VolumeAdjustmentPlan: Equatable {
    let fraction: Double
    let shouldUnmute: Bool
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
