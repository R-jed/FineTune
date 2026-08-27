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

    @Test("presentation clamps invalid display fractions into the normalized range")
    func presentationClampsFractions() {
        let low = VolumePresentationState(storedFraction: -1, isMuted: false, sourceIsActive: false)
        let high = VolumePresentationState(storedFraction: 2, isMuted: false, sourceIsActive: false)

        #expect(low.displayFraction == 0)
        #expect(low.displayPercent == 0)
        #expect(high.displayFraction == 1)
        #expect(high.displayPercent == 100)
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
