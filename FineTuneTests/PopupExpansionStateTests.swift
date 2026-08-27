import Testing
@testable import FineTune

@Suite("PopupExpansionState")
struct PopupExpansionStateTests {
    @Test("EQ can close immediately without an animation lock")
    func appExpansionReversesImmediately() {
        var state = PopupExpansionState()

        #expect(state.toggleApp("spotify"))
        #expect(state.appID == "spotify")

        #expect(state.toggleApp("spotify") == false)
        #expect(state.appID == nil)
    }

    @Test("Opening another EQ retargets immediately")
    func appExpansionRetargets() {
        var state = PopupExpansionState()

        #expect(state.toggleApp("spotify"))
        #expect(state.toggleApp("chrome"))
        #expect(state.appID == "chrome")
    }

    @Test("App and device expansions are mutually exclusive")
    func expansionKindsAreExclusive() {
        var state = PopupExpansionState()

        #expect(state.toggleDevice("output-a"))
        #expect(state.deviceUID == "output-a")
        #expect(state.appID == nil)

        #expect(state.toggleApp("spotify"))
        #expect(state.appID == "spotify")
        #expect(state.deviceUID == nil)
    }

    @Test("Reset collapses all structural expansion")
    func resetCollapsesEverything() {
        var state = PopupExpansionState()
        _ = state.toggleApp("spotify")

        state.reset()

        #expect(state.appID == nil)
        #expect(state.deviceUID == nil)
    }
}
