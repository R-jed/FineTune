// FineTune/Audio/Engine/TapProcessorGenerations.swift

/// Mutable DSP state owned by one Core Audio IO proc generation.
/// The IO proc closure captures this object at creation. Crossfade role promotion
/// may change callback role but never its mutable DSP identity.
final class TapProcessorState: @unchecked Sendable {
    nonisolated(unsafe) var eqProcessor: EQProcessor?
    nonisolated(unsafe) var autoEQProcessor: AutoEQProcessor?
    nonisolated(unsafe) var loudnessCompensator: LoudnessCompensator?

    private nonisolated let loudnessEqualizerReference = RealtimeRetainedReference<LoudnessEqualizer>()

    /// Keeps realtime use inside the reader-quiescence boundary so a replaced
    /// processor cannot be deinitialized by the HAL callback after retirement.
    @inline(__always)
    nonisolated func withLoudnessEqualizer(_ body: (LoudnessEqualizer?) -> Void) {
        loudnessEqualizerReference.withBorrowedValue { unmanaged in
            body(unmanaged?.takeUnretainedValue())
        }
    }

    /// Loudness processor publication belongs to the control plane. Keeping this
    /// MainActor-isolated prevents future HAL callbacks from replacing ownership.
    @MainActor
    func replaceLoudnessEqualizer(with processor: LoudnessEqualizer?) {
        loudnessEqualizerReference.replace(with: processor)
    }

    @MainActor
    var hasLoudnessEqualizer: Bool {
        var result = false
        withLoudnessEqualizer { result = $0 != nil }
        return result
    }

    @MainActor
    var loudnessEqualizerSettings: LoudnessEqualizerSettings? {
        var result: LoudnessEqualizerSettings?
        withLoudnessEqualizer { result = $0?.currentSettings }
        return result
    }
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
