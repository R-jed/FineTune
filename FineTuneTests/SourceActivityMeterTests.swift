// FineTuneTests/SourceActivityMeterTests.swift

import Testing
@testable import FineTune

@Suite("Source activity meter")
struct SourceActivityMeterTests {
    private let tolerance: Float = 1e-5

    @Test("Peak extraction uses absolute magnitude")
    func peakExtractionUsesAbsoluteMagnitude() {
        let samples: [Float] = [0.1, -1.0, 0.25, 0.75]

        let peak = samples.withUnsafeBufferPointer { buffer in
            SourceActivityMeter.maximumMagnitude(buffer.baseAddress!, count: buffer.count)
        }

        #expect(abs(peak - 1.0) < tolerance)
    }

    @Test("Interleaved right-channel-only peak is detected")
    func interleavedRightChannelPeakIsDetected() {
        // L, R, L, R. The old stride-by-channel-count scan only inspected indices 0 and 2.
        let interleavedStereo: [Float] = [0.0, 0.9, 0.0, -1.0]

        let peak = interleavedStereo.withUnsafeBufferPointer { buffer in
            SourceActivityMeter.maximumMagnitude(buffer.baseAddress!, count: buffer.count)
        }

        #expect(abs(peak - 1.0) < tolerance)
    }

    @Test("Attack is immediate and clamps display to full scale")
    func attackIsImmediateAndClamped() {
        var level: Float = 0
        var holdFramesRemaining = 0

        SourceActivityMeter.advance(
            level: &level,
            holdFramesRemaining: &holdFramesRemaining,
            rawPeak: 1.4,
            frameCount: 256,
            sampleRate: 48_000
        )

        #expect(level == 1.0)
        #expect(holdFramesRemaining == 4_800)
    }

    @Test("Transient remains visible for 100 ms of audio time")
    func transientHoldUsesAudioTime() {
        var level: Float = 0
        var holdFramesRemaining = 0

        SourceActivityMeter.advance(
            level: &level,
            holdFramesRemaining: &holdFramesRemaining,
            rawPeak: 1.0,
            frameCount: 256,
            sampleRate: 48_000
        )

        SourceActivityMeter.advance(
            level: &level,
            holdFramesRemaining: &holdFramesRemaining,
            rawPeak: 0,
            frameCount: 4_608,
            sampleRate: 48_000
        )

        #expect(level == 1.0)
        #expect(holdFramesRemaining == 192)

        SourceActivityMeter.advance(
            level: &level,
            holdFramesRemaining: &holdFramesRemaining,
            rawPeak: 0,
            frameCount: 192,
            sampleRate: 48_000
        )

        #expect(level == 1.0)
        #expect(holdFramesRemaining == 0)
    }

    @Test("Hold ending mid-buffer decays the remaining frames")
    func holdBoundaryIsFrameExact() {
        var level: Float = 1.0
        var holdFramesRemaining = 192

        SourceActivityMeter.advance(
            level: &level,
            holdFramesRemaining: &holdFramesRemaining,
            rawPeak: 0,
            frameCount: 512,
            sampleRate: 48_000
        )

        // 192 frames are held, then the remaining 320 frames release at 24 dB/s.
        let expected: Float = 0.98174794
        #expect(holdFramesRemaining == 0)
        #expect(abs(level - expected) < tolerance)
    }

    @Test("One second release drops 24 dB")
    func releaseIsTwentyFourDBPerSecond() {
        var level: Float = 1.0
        var holdFramesRemaining = 0

        SourceActivityMeter.advance(
            level: &level,
            holdFramesRemaining: &holdFramesRemaining,
            rawPeak: 0,
            frameCount: 48_000,
            sampleRate: 48_000
        )

        let expected: Float = 0.063095734  // 10^(-24/20)
        #expect(abs(level - expected) < tolerance)
    }

    @Test("Release depends on elapsed time, not callback buffer size")
    func releaseIsBufferSizeIndependent() {
        var singleBufferLevel: Float = 1.0
        var singleHold = 0
        SourceActivityMeter.advance(
            level: &singleBufferLevel,
            holdFramesRemaining: &singleHold,
            rawPeak: 0,
            frameCount: 48_000,
            sampleRate: 48_000
        )

        var manyBufferLevel: Float = 1.0
        var manyHold = 0
        for _ in 0..<100 {
            SourceActivityMeter.advance(
                level: &manyBufferLevel,
                holdFramesRemaining: &manyHold,
                rawPeak: 0,
                frameCount: 480,
                sampleRate: 48_000
            )
        }

        #expect(abs(singleBufferLevel - manyBufferLevel) < tolerance)
    }

    @Test("Equivalent elapsed time matches at 44.1 and 48 kHz")
    func releaseIsSampleRateIndependent() {
        var level441: Float = 1.0
        var hold441 = 0
        SourceActivityMeter.advance(
            level: &level441,
            holdFramesRemaining: &hold441,
            rawPeak: 0,
            frameCount: 22_050,
            sampleRate: 44_100
        )

        var level480: Float = 1.0
        var hold480 = 0
        SourceActivityMeter.advance(
            level: &level480,
            holdFramesRemaining: &hold480,
            rawPeak: 0,
            frameCount: 24_000,
            sampleRate: 48_000
        )

        #expect(abs(level441 - level480) < tolerance)
    }

    @Test("Sustained source below the minus 60 dBFS floor stays at zero")
    func sustainedSubFloorSourceStaysAtZero() {
        var level: Float = 0
        var holdFramesRemaining = 0

        for _ in 0..<10 {
            SourceActivityMeter.advance(
                level: &level,
                holdFramesRemaining: &holdFramesRemaining,
                rawPeak: 0.0005,
                frameCount: 480,
                sampleRate: 48_000
            )
        }

        #expect(level == 0)
        #expect(holdFramesRemaining == 0)
    }

    @Test("Meter settles to zero below the minus 60 dBFS display floor")
    func belowDisplayFloorSettlesToZero() {
        var level: Float = 1.0
        var holdFramesRemaining = 0

        SourceActivityMeter.advance(
            level: &level,
            holdFramesRemaining: &holdFramesRemaining,
            rawPeak: 0,
            frameCount: 144_000,
            sampleRate: 48_000
        )

        #expect(level == 0)
    }
}
