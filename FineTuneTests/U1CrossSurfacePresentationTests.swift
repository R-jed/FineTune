import Testing
@testable import FineTune

@Suite("U1 cross-surface presentation")
struct U1CrossSurfacePresentationTests {
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
}
