import Testing
@testable import FineTune

@Suite("U1 volume presentation state")
struct AudioPresentationStateTests {
    @Test("unmuted non-zero volume preserves the stored display fraction")
    func unmutedVolumePreservesStoredFraction() {
        let state = VolumePresentationState(
            storedFraction: 0.65,
            isMuted: false,
            sourceIsActive: true
        )

        #expect(state.displayFraction == 0.65)
        #expect(state.displayPercent == 65)
        #expect(state.displaysMuted == false)
        #expect(state.hasAudibleOutput == true)
        #expect(state.sourceActivityVisible == true)
    }

    @Test("muted non-zero volume displays zero without hiding source activity")
    func mutedVolumeDisplaysZero() {
        let state = VolumePresentationState(
            storedFraction: 0.65,
            isMuted: true,
            sourceIsActive: true
        )

        #expect(state.displayFraction == 0)
        #expect(state.displayPercent == 0)
        #expect(state.displaysMuted == true)
        #expect(state.hasAudibleOutput == false)
        #expect(state.sourceActivityVisible == true)
        #expect(state.unmuteFraction() == 0.65)
    }

    @Test("zero volume uses muted-equivalent presentation even without an explicit mute flag")
    func zeroVolumeUsesMutedEquivalentPresentation() {
        let state = VolumePresentationState(
            storedFraction: 0,
            isMuted: false,
            sourceIsActive: false
        )

        #expect(state.displayFraction == 0)
        #expect(state.displayPercent == 0)
        #expect(state.displaysMuted == true)
        #expect(state.hasAudibleOutput == false)
        #expect(state.sourceActivityVisible == false)
    }

    @Test("explicit unmute from zero falls back to fifty percent when there is no remembered value")
    func unmuteFromZeroUsesSharedFallback() {
        let state = VolumePresentationState(
            storedFraction: 0,
            isMuted: true,
            sourceIsActive: false
        )

        #expect(state.unmuteFraction() == 0.5)
    }

    @Test("explicit unmute from zero prefers a remembered non-zero value")
    func unmuteFromZeroPrefersRememberedValue() {
        let state = VolumePresentationState(
            storedFraction: 0,
            isMuted: true,
            sourceIsActive: false
        )

        #expect(state.unmuteFraction(rememberedNonZeroFraction: 0.3) == 0.3)
    }

    @Test("mute toggle preserves a non-zero stored value while unmuting")
    func muteToggleRestoresStoredValue() {
        let plan = VolumePresentationState(
            storedFraction: 0.65,
            isMuted: true,
            sourceIsActive: false
        ).planMuteToggle()

        #expect(plan == VolumeMuteTogglePlan(fraction: 0.65, muted: false))
    }

    @Test("mute toggle from muted zero prefers remembered value then fallback")
    func muteToggleFromZeroUsesSharedRestorePolicy() {
        let state = VolumePresentationState(
            storedFraction: 0,
            isMuted: true,
            sourceIsActive: false
        )

        #expect(
            state.planMuteToggle(rememberedNonZeroFraction: 0.3)
                == VolumeMuteTogglePlan(fraction: 0.3, muted: false)
        )
        #expect(
            state.planMuteToggle()
                == VolumeMuteTogglePlan(fraction: 0.5, muted: false)
        )
    }

    @Test("mute-equivalent zero activates as explicit unmute")
    func zeroUnmutedMuteControlUsesFallback() {
        let plan = VolumePresentationState(
            storedFraction: 0,
            isMuted: false,
            sourceIsActive: false
        ).planMuteToggle()

        #expect(plan == VolumeMuteTogglePlan(fraction: 0.5, muted: false))
    }

    @Test("visible zero threshold follows the rounded display percent")
    func visibleZeroThresholdMatchesRoundedPercent() {
        let belowHalfPercent = VolumePresentationState(
            storedFraction: 0.004,
            isMuted: true,
            sourceIsActive: false
        )
        let aboveHalfPercent = VolumePresentationState(
            storedFraction: 0.006,
            isMuted: true,
            sourceIsActive: false
        )

        #expect(belowHalfPercent.displayPercent == 0)
        #expect(belowHalfPercent.displaysMuted == true)
        #expect(belowHalfPercent.planAdjustment(to: 0.004).shouldUnmute == false)
        #expect(aboveHalfPercent.planAdjustment(to: 0.006).shouldUnmute == true)
    }

    @Test("presentation clamps invalid display fractions into the normalized range")
    func presentationClampsFractions() {
        let low = VolumePresentationState(storedFraction: -1, isMuted: false, sourceIsActive: false)
        let high = VolumePresentationState(storedFraction: 2, isMuted: false, sourceIsActive: false)

        #expect(low.displayFraction == 0)
        #expect(low.displayPercent == 0)
        #expect(high.displayFraction == 1)
        #expect(high.displayPercent == 100)
    }

    @Test("software adjustment while muted writes target volume before unmuting")
    func softwareAdjustmentUsesVolumeThenMuteOrder() {
        let plan = OutputVolumeCommandPlan.adjustment(
            currentFraction: 0.6,
            isMuted: true,
            tier: .software,
            requestedFraction: 0.7
        )
        var writes: [String] = []

        plan.apply(
            setVolume: { _ in writes.append("volume") },
            setMute: { _ in writes.append("mute") }
        )

        #expect(plan.muted == false)
        #expect(plan.writeOrder == .volumeThenMute)
        #expect(writes == ["volume", "mute"])
    }

    @Test("DDC adjustment while muted unmutes before writing the requested target")
    func ddcAdjustmentUsesMuteThenVolumeOrder() {
        let plan = OutputVolumeCommandPlan.adjustment(
            currentFraction: 0.8,
            isMuted: true,
            tier: .ddc,
            requestedFraction: 0.9
        )
        var writes: [String] = []

        plan.apply(
            setVolume: { _ in writes.append("volume") },
            setMute: { _ in writes.append("mute") }
        )

        #expect(plan.muted == false)
        #expect(plan.writeOrder == .muteThenVolume)
        #expect(writes == ["mute", "volume"])
    }

    @Test("Output step owns gain-to-slider mapping and backend unmute ordering")
    func outputStepOwnsMappingAndOrder() {
        let software = OutputVolumeCommandPlan.step(
            currentGain: 0.36,
            isMuted: true,
            tier: .software,
            delta: 1.0 / 16.0
        )
        #expect(abs(software.fraction - 0.6625) < 1e-6)
        #expect(abs(Double(software.gain) - 0.43890625) < 1e-6)
        #expect(software.muted == false)
        #expect(software.writeOrder == .volumeThenMute)

        let ddc = OutputVolumeCommandPlan.step(
            currentGain: 0.8,
            isMuted: true,
            tier: .ddc,
            delta: 1.0 / 16.0
        )
        #expect(abs(ddc.fraction - 0.8625) < 1e-6)
        #expect(ddc.muted == false)
        #expect(ddc.writeOrder == .muteThenVolume)
    }

    @Test("DDC zero-history unmute writes fallback after backend restore")
    func ddcMuteToggleFallbackUsesMuteThenVolumeOrder() {
        let plan = OutputVolumeCommandPlan.muteToggle(
            currentFraction: 0,
            isMuted: true,
            tier: .ddc
        )
        var writes: [String] = []

        plan.apply(
            setVolume: { value in writes.append("volume:\(value)") },
            setMute: { value in writes.append("mute:\(value)") }
        )

        #expect(plan.fraction == 0.5)
        #expect(plan.gain == 0.5)
        #expect(plan.writeOrder == .muteThenVolume)
        #expect(writes == ["mute:false", "volume:0.5"])
    }

    @Test("software zero-history unmute installs mapped fallback before backend restore")
    func softwareMuteToggleFallbackUsesVolumeThenMuteOrder() {
        let plan = OutputVolumeCommandPlan.muteToggle(
            currentFraction: 0,
            isMuted: true,
            tier: .software
        )
        var writes: [String] = []

        plan.apply(
            setVolume: { value in writes.append("volume:\(value)") },
            setMute: { value in writes.append("mute:\(value)") }
        )

        #expect(plan.fraction == 0.5)
        #expect(plan.gain == 0.25)
        #expect(plan.writeOrder == .volumeThenMute)
        #expect(writes == ["volume:0.25", "mute:false"])
    }

    @Test("zero adjustment preserves explicit mute state across output surfaces")
    func zeroAdjustmentKeepsMutedEquivalentState() {
        let plan = OutputVolumeCommandPlan.adjustment(
            currentFraction: 0.1,
            isMuted: false,
            tier: .software,
            requestedFraction: 0
        )

        #expect(plan.muted == false)
        #expect(plan.shouldWriteMute == false)
    }

    @Test("App adjustment installs gain before unmuting and keeps zero mute-equivalent")
    func appAdjustmentOwnsSharedOrderAndZeroPolicy() {
        let audible = AppVolumeCommandPlan.adjustment(
            currentFraction: 0.6,
            isMuted: true,
            requestedFraction: 0.7
        )
        var writes: [String] = []
        audible.apply(
            setVolume: { _ in writes.append("volume") },
            setMute: { _ in writes.append("mute") }
        )

        #expect(audible.muted == false)
        #expect(writes == ["volume", "mute"])

        let zero = AppVolumeCommandPlan.adjustment(
            currentFraction: 0.1,
            isMuted: false,
            requestedFraction: 0
        )
        #expect(zero.gain == 0)
        #expect(zero.muted == false)
        #expect(zero.shouldWriteMute == false)
    }

    @Test("App explicit unmute from zero maps shared fifty-percent fallback before opening tap")
    func appMuteToggleZeroFallbackUsesVolumeThenMuteOrder() {
        let plan = AppVolumeCommandPlan.muteToggle(currentGain: 0, isMuted: true)
        var writes: [String] = []
        plan.apply(
            setVolume: { value in writes.append("volume:\(value)") },
            setMute: { value in writes.append("mute:\(value)") }
        )

        #expect(plan.fraction == 0.5)
        #expect(plan.gain == 0.25)
        #expect(writes == ["volume:0.25", "mute:false"])
    }
}

@Suite("U1 app presence grouping")
struct AppPresenceGroupTests {
    @Test("running unpinned app belongs to the normal group")
    func runningNormalApp() {
        #expect(AppPresenceGroup.resolve(isRunning: true, isPinned: false, isHidden: false) == .normal)
    }

    @Test("pinned app belongs to the pinned group whether running or inactive")
    func pinnedAppStaysPinned() {
        #expect(AppPresenceGroup.resolve(isRunning: true, isPinned: true, isHidden: false) == .pinned)
        #expect(AppPresenceGroup.resolve(isRunning: false, isPinned: true, isHidden: false) == .pinned)
    }

    @Test("hidden state wins over running and pinned state")
    func hiddenStateWins() {
        #expect(AppPresenceGroup.resolve(isRunning: true, isPinned: true, isHidden: true) == .hidden)
        #expect(AppPresenceGroup.resolve(isRunning: true, isPinned: false, isHidden: true) == .hidden)
    }

    @Test("inactive unpinned visible app is absent")
    func inactiveUnpinnedAppIsAbsent() {
        #expect(AppPresenceGroup.resolve(isRunning: false, isPinned: false, isHidden: false) == .absent)
    }
}
