import Testing
@testable import FineTune

@Suite("PopupExpansionState")
struct PopupExpansionStateTests {
    @Test("EQ can close immediately without an animation lock")
    func appExpansionReversesImmediately() {
        var state = PopupExpansionState()

        let opened = state.toggleApp("spotify")
        #expect(opened)
        #expect(state.appID == "spotify")

        let closed = state.toggleApp("spotify")
        #expect(closed == false)
        #expect(state.appID == nil)
    }

    @Test("Opening another EQ retargets immediately")
    func appExpansionRetargets() {
        var state = PopupExpansionState()

        let openedSpotify = state.toggleApp("spotify")
        #expect(openedSpotify)

        let openedChrome = state.toggleApp("chrome")
        #expect(openedChrome)
        #expect(state.appID == "chrome")
    }

    @Test("App and device expansions are mutually exclusive")
    func expansionKindsAreExclusive() {
        var state = PopupExpansionState()

        let openedDevice = state.toggleDevice("output-a")
        #expect(openedDevice)
        #expect(state.deviceUID == "output-a")
        #expect(state.appID == nil)

        let openedApp = state.toggleApp("spotify")
        #expect(openedApp)
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
