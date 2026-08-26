// FineTune/Audio/EQ/BiquadProcessor.swift
import Foundation
import Accelerate
import Synchronization
import Darwin
import os

private struct BiquadSetupBox: @unchecked Sendable {
    let setup: vDSP_biquad_Setup
}

/// Internal seam between the HAL reader and non-RT writers.
///
/// Readers register before touching realtime-visible biquad state. When the last
/// reader leaves, the quiescence epoch advances. A writer that publishes a new
/// generation can wait for an epoch after that publication instead of guessing
/// with a wall-clock grace period.
///
/// `enterRead()` / `leaveRead()` are called from the realtime callback and use
/// only atomic integer operations. `waitForReaders(after:)` is non-RT and may yield.
final class RealtimeQuiescenceGate: @unchecked Sendable {
    struct Checkpoint: Sendable {
        fileprivate let epoch: UInt
    }

    private let activeReaders = Atomic<UInt>(0)
    private let quiescenceEpoch = Atomic<UInt>(0)

    @inline(__always)
    func enterRead() {
        activeReaders.wrappingAdd(1, ordering: .sequentiallyConsistent)
    }

    @inline(__always)
    func leaveRead() {
        let result = activeReaders.wrappingSubtract(1, ordering: .sequentiallyConsistent)
        if result.newValue == 0 {
            quiescenceEpoch.wrappingAdd(1, ordering: .sequentiallyConsistent)
        }
    }

    func checkpoint() -> Checkpoint {
        Checkpoint(epoch: quiescenceEpoch.load(ordering: .sequentiallyConsistent))
    }

    /// Waits until every reader that could have been active at `checkpoint`
    /// has passed through a zero-reader state.
    ///
    /// A later reader may already be active when this returns. That is safe for
    /// resource retirement because a later reader can only observe state
    /// published after the caller captured the checkpoint.
    func waitForReaders(after checkpoint: Checkpoint) {
        while true {
            if activeReaders.load(ordering: .sequentiallyConsistent) == 0 {
                return
            }
            if quiescenceEpoch.load(ordering: .sequentiallyConsistent) != checkpoint.epoch {
                return
            }
            sched_yield()
        }
    }
}

/// Base class for RT-safe biquad filter processors.
///
/// Manages delay buffers, atomic setup publication, quiescent setup retirement,
/// and the core stereo biquad processing loop. Subclasses provide coefficient
/// computation via `recomputeCoefficients()` and optional pre-processing via
/// `preProcess()`.
///
/// ## RT-Safety
/// `process()` runs on CoreAudio's HAL I/O thread. It registers as a realtime
/// reader before loading the enabled flag or setup pointer. Writers publish
/// setup changes atomically and reclaim old setups only after a real quiescent
/// point. Delay-buffer resets disable new processing and wait for prior readers
/// before mutating shared filter state.
///
/// ## Subclasses
/// - `EQProcessor`: Per-app 10-band graphic EQ
/// - `AutoEQProcessor`: Per-device headphone correction
class BiquadProcessor: @unchecked Sendable, BiquadProcessable {

    let logger: Logger

    /// Current sample rate in Hz. Main thread only.
    private(set) var sampleRate: Double

    // MARK: - RT-Safe State

    /// Current vDSP setup published atomically to the HAL reader.
    private let eqSetup = Atomic<OpaquePointer?>(nil)

    /// Processing enable flag shared with the HAL reader.
    private let isEnabledStorage = Atomic<Bool>(false)

    /// Tracks realtime readers so old setups and delay buffers are not mutated
    /// while a callback can still be using them.
    private let quiescence = RealtimeQuiescenceGate()

    // MARK: - Pre-allocated Delay Buffers

    private let delayBufferL: UnsafeMutablePointer<Float>
    private let delayBufferR: UnsafeMutablePointer<Float>
    private let delayBufferSize: Int

    /// Whether biquad processing is active (RT-safe read).
    var isEnabled: Bool {
        isEnabledStorage.load(ordering: .sequentiallyConsistent)
    }

    /// Set the processing enable flag. Main thread only.
    func setEnabled(_ enabled: Bool) {
        isEnabledStorage.store(enabled, ordering: .sequentiallyConsistent)
    }

    // MARK: - Init / Deinit

    /// - Parameters:
    ///   - sampleRate: Initial device sample rate in Hz.
    ///   - maxSections: Maximum number of biquad sections. Determines delay buffer size: `(2 * maxSections) + 2`.
    ///   - category: Logger category for this processor instance.
    ///   - initiallyEnabled: Whether processing starts enabled. Default `false`.
    init(sampleRate: Double, maxSections: Int, category: String, initiallyEnabled: Bool = false) {
        self.sampleRate = sampleRate
        self.logger = Logger(subsystem: "com.finetuneapp.FineTune", category: category)
        self.delayBufferSize = (2 * maxSections) + 2

        isEnabledStorage.store(initiallyEnabled, ordering: .sequentiallyConsistent)

        delayBufferL = .allocate(capacity: delayBufferSize)
        delayBufferL.initialize(repeating: 0, count: delayBufferSize)
        delayBufferR = .allocate(capacity: delayBufferSize)
        delayBufferR.initialize(repeating: 0, count: delayBufferSize)
    }

    deinit {
        let oldSetup = eqSetup.exchange(nil, ordering: .sequentiallyConsistent)
        let checkpoint = quiescence.checkpoint()
        quiescence.waitForReaders(after: checkpoint)

        if let oldSetup {
            vDSP_biquad_DestroySetup(oldSetup)
        }
        delayBufferL.deallocate()
        delayBufferR.deallocate()
    }

    // MARK: - Setup Management (main thread)

    /// Publishes a new biquad setup.
    ///
    /// Ordinary coefficient changes intentionally keep the existing delay
    /// buffers so the filter state evolves continuously. The replaced setup is
    /// retired off the realtime thread after a proven quiescent point.
    func swapSetup(_ newSetup: vDSP_biquad_Setup?) {
        let oldSetup = eqSetup.exchange(newSetup, ordering: .sequentiallyConsistent)
        guard let oldSetup, oldSetup != newSetup else { return }

        let checkpoint = quiescence.checkpoint()
        let gate = quiescence
        let retired = BiquadSetupBox(setup: oldSetup)
        DispatchQueue.global(qos: .utility).async {
            gate.waitForReaders(after: checkpoint)
            vDSP_biquad_DestroySetup(retired.setup)
        }
    }

    /// Reset delay buffers after preventing new processing and waiting for all
    /// callbacks that could have entered before the disable to leave.
    ///
    /// Call from the main thread.
    func resetDelayBuffers() {
        let wasEnabled = isEnabledStorage.exchange(false, ordering: .sequentiallyConsistent)
        let checkpoint = quiescence.checkpoint()
        quiescence.waitForReaders(after: checkpoint)

        memset(delayBufferL, 0, delayBufferSize * MemoryLayout<Float>.size)
        memset(delayBufferR, 0, delayBufferSize * MemoryLayout<Float>.size)

        isEnabledStorage.store(wasEnabled, ordering: .sequentiallyConsistent)
    }

    /// Update sample rate and recompute coefficients.
    ///
    /// The new setup is published while processing is disabled. After every
    /// callback that could have observed the previous setup has passed a
    /// quiescent point, the old setup is destroyed and delay state is reset.
    func updateSampleRate(_ newRate: Double) {
        dispatchPrecondition(condition: .onQueue(.main))
        let oldRate = sampleRate
        guard newRate != sampleRate else { return }
        sampleRate = newRate

        guard let (coefficients, sectionCount) = recomputeCoefficients() else {
            // No state loaded — rate saved for future use
            return
        }

        let newSetup = coefficients.withUnsafeBufferPointer { ptr in
            vDSP_biquad_CreateSetup(ptr.baseAddress!, vDSP_Length(sectionCount))
        }

        guard let newSetup else {
            sampleRate = oldRate
            logger.warning("vDSP_biquad_CreateSetup returned nil at \(newRate, format: .fixed(precision: 0))Hz")
            return
        }

        let wasEnabled = isEnabledStorage.exchange(false, ordering: .sequentiallyConsistent)
        let oldSetup = eqSetup.exchange(newSetup, ordering: .sequentiallyConsistent)
        let checkpoint = quiescence.checkpoint()
        quiescence.waitForReaders(after: checkpoint)

        memset(delayBufferL, 0, delayBufferSize * MemoryLayout<Float>.size)
        memset(delayBufferR, 0, delayBufferSize * MemoryLayout<Float>.size)

        if let oldSetup, oldSetup != newSetup {
            vDSP_biquad_DestroySetup(oldSetup)
        }

        isEnabledStorage.store(wasEnabled, ordering: .sequentiallyConsistent)

        logger.info("Sample rate: \(oldRate, format: .fixed(precision: 0))Hz → \(newRate, format: .fixed(precision: 0))Hz")
    }

    // MARK: - Subclass Hooks

    /// Override to provide coefficients for the current state at the current sample rate.
    /// Called during `updateSampleRate()`. Return `nil` if no state is loaded.
    ///
    /// - Returns: Tuple of (flat coefficient array in vDSP format, number of biquad sections),
    ///   or `nil` to skip recomputation.
    func recomputeCoefficients() -> (coefficients: [Double], sectionCount: Int)? {
        return nil
    }

    /// Override to apply pre-processing before the biquad cascade (e.g. preamp gain).
    /// Called after input is copied to output, before biquad processing. **Must be RT-safe.**
    ///
    /// Default implementation is a no-op.
    func preProcess(output: UnsafeMutablePointer<Float>, frameCount: Int) {
        // No-op — subclasses override
    }

    // MARK: - Audio Processing (RT-safe)

    /// Process stereo interleaved audio. RT-safe: no allocations, locks, ObjC, or I/O.
    /// Can process in-place (input == output).
    ///
    /// - Parameters:
    ///   - input: Input buffer (stereo interleaved Float32).
    ///   - output: Output buffer (stereo interleaved Float32).
    ///   - frameCount: Number of stereo frames (total samples / 2).
    func process(input: UnsafePointer<Float>, output: UnsafeMutablePointer<Float>, frameCount: Int) {
        quiescence.enterRead()
        defer { quiescence.leaveRead() }

        let enabled = isEnabledStorage.load(ordering: .sequentiallyConsistent)
        let setup = eqSetup.load(ordering: .sequentiallyConsistent)

        // Bypass: copy input to output
        guard enabled, let setup else {
            if input != UnsafePointer(output) {
                memcpy(output, input, frameCount * 2 * MemoryLayout<Float>.size)
            }
            return
        }

        // Copy input to output for in-place processing
        if input != UnsafePointer(output) {
            memcpy(output, input, frameCount * 2 * MemoryLayout<Float>.size)
        }

        // Subclass hook for pre-processing (e.g. preamp gain)
        preProcess(output: output, frameCount: frameCount)

        // Stereo biquad cascade: stride=2 for interleaved L/R data
        vDSP_biquad(setup, delayBufferL, output, 2, output, 2, vDSP_Length(frameCount))
        vDSP_biquad(setup, delayBufferR, output.advanced(by: 1), 2, output.advanced(by: 1), 2, vDSP_Length(frameCount))

        // NaN safety net — pathological coefficients can produce NaN that
        // propagates through the entire downstream chain
        if output[0].isNaN || output[1].isNaN {
            memset(delayBufferL, 0, delayBufferSize * MemoryLayout<Float>.size)
            memset(delayBufferR, 0, delayBufferSize * MemoryLayout<Float>.size)
            memset(output, 0, frameCount * 2 * MemoryLayout<Float>.size)
        }
    }
}
