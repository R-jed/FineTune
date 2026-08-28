import Testing
@testable import FineTune

@Suite("U1 cross-surface presentation")
struct U1CrossSurfacePresentationTests {
    private func device() -> AudioDevice {
        AudioDevice(
            id: 1,
            uid: "test-device",
            name: "Test Device",
            icon: nil,
            supportsAutoEQ: false
        )
    }

    @Test("Speaker menu icon treats zero output as muted-equivalent")
    func speakerMenuIconUsesMutedEquivalentAtZero() {
        #expect(
            MenuBarIconState.baseline(
                style: .speaker,
                volume: 0,
                muted: false
            ) == .speakerMuted
        )
    }

    @Test("Classic HUD uses the shared muted-equivalent zero presentation")
    func classicHUDUsesSharedZeroPresentation() {
        let zero = ClassicStyleHUD(sliderFraction: 0, mute: false)
        let muted = ClassicStyleHUD(sliderFraction: 0.75, mute: true)

        #expect(zero.displayedPercentForTest == 0)
        #expect(zero.displayMuteForTest)
        #expect(muted.displayedPercentForTest == 0)
        #expect(muted.displayMuteForTest)
    }

    @Test("Output device row hides stored volume while muted")
    func outputDeviceRowUsesEffectiveVolumePresentation() {
        let row = DeviceRow(
            device: device(),
            isDefault: true,
            volume: 0.75,
            isMuted: true,
            onSetDefault: {},
            onVolumeCommand: { _ in }
        )

        #expect(row.displayedPercentageForTest == 0)
        #expect(row.showMutedIconForTest)
    }

    @Test("Input device row hides stored volume while muted")
    func inputDeviceRowUsesEffectiveVolumePresentation() {
        let row = InputDeviceRow(
            device: device(),
            isDefault: true,
            volume: 0.75,
            isMuted: true,
            onSetDefault: {},
            onUserVolumeChange: { _ in },
            onUserMuteToggle: {}
        )

        #expect(row.displayedPercentageForTest == 0)
        #expect(row.showMutedIconForTest)
    }

    @Test("Shared adjustment plan unmutes only for a visible value above zero")
    func sharedAdjustmentPlanControlsAutoUnmute() {
        let muted = VolumePresentationState(
            storedFraction: 0.8,
            isMuted: true,
            sourceIsActive: false
        )

        #expect(muted.planAdjustment(to: 0).shouldUnmute == false)
        #expect(muted.planAdjustment(to: 0.004).shouldUnmute == false)
        #expect(muted.planAdjustment(to: 0.01).shouldUnmute == true)
        #expect(muted.planAdjustment(to: 2).fraction == 1)
        #expect(muted.planAdjustment(to: -1).fraction == 0)
    }
}
