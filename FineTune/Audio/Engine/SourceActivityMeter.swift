// FineTune/Audio/Engine/SourceActivityMeter.swift
import Accelerate
import Darwin

/// Pure meter math for the per-app source-activity display.
///
/// This code is called from Core Audio's HAL callback. Keep it real-time safe:
/// no allocation, locking, Objective-C messaging, logging, or I/O.
enum SourceActivityMeter {
    static let releaseDBPerSecond: Float = 24
    static let transientHoldSeconds: Float = 0.100

    private static let displayFloorAmplitude: Float = 0.001  // -60 dBFS

    /// Returns the maximum absolute magnitude in a contiguous Float buffer.
    /// Every Float is inspected, so the result does not depend on whether channels
    /// are interleaved or split across separate AudioBuffers.
    @inline(__always)
    static func maximumMagnitude(_ samples: UnsafePointer<Float>, count: Int) -> Float {
        guard count > 0 else { return 0 }

        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(count))
        return peak.isFinite ? peak : 0
    }

    /// Advances one source meter by one audio callback.
    ///
    /// Attack is immediate. A short audio-time hold makes one-buffer transients
    /// observable by the 30 fps UI. After the hold, release is expressed in dB/s,
    /// making it independent of callback buffer size and device sample rate.
    @inline(__always)
    static func advance(
        level: inout Float,
        holdFramesRemaining: inout Int,
        rawPeak: Float,
        frameCount: Int,
        sampleRate: Float
    ) {
        guard frameCount > 0 else { return }

        let finitePeak = rawPeak.isFinite ? rawPeak : 0
        let clampedPeak = min(max(finitePeak, 0), 1)
        let peak = clampedPeak >= displayFloorAmplitude ? clampedPeak : 0
        let validSampleRate = sampleRate.isFinite && sampleRate > 0 ? sampleRate : 48_000

        if peak > 0, peak >= level {
            level = peak
            holdFramesRemaining = Int(validSampleRate * transientHoldSeconds)
            return
        }

        var releaseFrames = frameCount
        if holdFramesRemaining > 0 {
            let heldFrames = min(holdFramesRemaining, releaseFrames)
            holdFramesRemaining -= heldFrames
            releaseFrames -= heldFrames
            guard releaseFrames > 0 else { return }
        }

        guard level > 0 else {
            level = 0
            return
        }

        let elapsedSeconds = Float(releaseFrames) / validSampleRate
        let releaseDB = releaseDBPerSecond * elapsedSeconds
        let releaseMultiplier = powf(10, -releaseDB / 20)
        level = max(peak, level * releaseMultiplier)

        if level < displayFloorAmplitude {
            level = 0
        }
    }
}
