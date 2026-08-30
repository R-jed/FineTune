import Testing
@testable import FineTune

@Suite("Popup page identity")
struct PopupPageTests {
    @Test("Entering management preserves the active direction")
    func enteringManagementPreservesDirection() {
        #expect(PopupPage.main(.output).enteringManagement() == .management(.output))
        #expect(PopupPage.main(.input).enteringManagement() == .management(.input))
    }

    @Test("Main-page Output/Input switch changes direction without persistence")
    func mainPageSwitchChangesDirectionOnly() {
        let transition = PopupPage.main(.output).selecting(.input)

        #expect(transition == .init(
            page: .main(.input),
            managementDirectionToPersist: nil
        ))
    }

    @Test("Management Output/Input switch preserves page depth and persists old owner")
    func managementSwitchPreservesPageDepth() {
        let outputToInput = PopupPage.management(.output).selecting(.input)
        #expect(outputToInput == .init(
            page: .management(.input),
            managementDirectionToPersist: .output
        ))

        let inputToOutput = PopupPage.management(.input).selecting(.output)
        #expect(inputToOutput == .init(
            page: .management(.output),
            managementDirectionToPersist: .input
        ))
    }

    @Test("Selecting the active direction is a no-op on every page depth")
    func sameDirectionSelectionIsNoOp() {
        #expect(PopupPage.main(.output).selecting(.output) == nil)
        #expect(PopupPage.main(.input).selecting(.input) == nil)
        #expect(PopupPage.management(.output).selecting(.output) == nil)
        #expect(PopupPage.management(.input).selecting(.input) == nil)
    }

    @Test("Direction exposes the current audio pane consistently")
    func directionReflectsPageIdentity() {
        #expect(PopupPage.main(.output).direction == .output)
        #expect(PopupPage.management(.output).direction == .output)
        #expect(PopupPage.main(.input).direction == .input)
        #expect(PopupPage.management(.input).direction == .input)
    }
}
