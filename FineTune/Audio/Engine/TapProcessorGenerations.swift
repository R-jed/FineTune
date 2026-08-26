// FineTune/Audio/Engine/TapProcessorGenerations.swift

/// Mutable DSP state owned by one Core Audio IO proc generation.
/// The IO proc closure captures this object at creation. Crossfade role promotion
/// may change callback role but never its mutable DSP identity.
final class TapProcessorState: @unchecked Sendable {
    nonisolated(unsafe) var eqProcessor: EQProcessor?
    nonisolated(unsafe) var autoEQProcessor: AutoEQProcessor?
    nonisolated(unsafe) var loudnessCompensator: LoudnessCompensator?
    nonisolated(unsafe) var loudnessEqualizerProcessor: LoudnessEqualizer?
}

@MainActor
final class TapProcessorGenerations {
    private(set) var primary = TapProcessorState()
    private(set) var secondary = TapProcessorState()

    func reset() {
        primary = TapProcessorState()
        secondary = TapProcessorState()
    }

    func resetSecondary() {
        secondary = TapProcessorState()
    }

    func replacePrimary(with state: TapProcessorState) {
        primary = state
    }

    func replaceSecondary(with state: TapProcessorState) {
        secondary = state
    }

    func promoteSecondary() {
        primary = secondary
        secondary = TapProcessorState()
    }
}
