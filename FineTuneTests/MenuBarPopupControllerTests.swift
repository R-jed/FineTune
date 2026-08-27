import CoreGraphics
import Testing
@testable import FineTune

@Suite("MenuBarPopupController", .serialized)
@MainActor
struct MenuBarPopupControllerTests {
    @Test("toggle is a no-op before the host attaches")
    func unattachedToggleIsSafe() {
        let controller = MenuBarPopupController()
        controller.toggle()
    }

    @Test("toggle calls the attached host directly")
    func attachedToggleRuns() {
        let controller = MenuBarPopupController()
        var callCount = 0
        controller.attach { callCount += 1 }

        controller.toggle()
        controller.toggle()

        #expect(callCount == 2)
    }

    @Test("reattaching replaces the old host callback")
    func reattachReplacesHandler() {
        let controller = MenuBarPopupController()
        var firstCount = 0
        var secondCount = 0

        controller.attach { firstCount += 1 }
        controller.attach { secondCount += 1 }
        controller.toggle()

        #expect(firstCount == 0)
        #expect(secondCount == 1)
    }

    @Test("detach makes later toggles safe no-ops")
    func detachStopsDelivery() {
        let controller = MenuBarPopupController()
        var callCount = 0
        controller.attach { callCount += 1 }
        controller.detach()

        controller.toggle()

        #expect(callCount == 0)
    }
}

@Suite("FineTuneMenuBarFrameCalculator")
struct FineTuneMenuBarFrameCalculatorTests {
    @Test("normal placement aligns under the status item")
    func normalPlacement() {
        let frame = FineTuneMenuBarFrameCalculator.frame(
            statusItemFrame: .init(x: 500, y: 900, width: 24, height: 24),
            contentSize: .init(width: 320, height: 420),
            screenVisibleFrame: .init(x: 0, y: 0, width: 1440, height: 900)
        )

        #expect(frame.origin.x == 498)
        #expect(frame.origin.y == 480)
        #expect(frame.size == .init(width: 320, height: 420))
    }

    @Test("right-edge overflow reverses alignment")
    func rightEdgeReverses() {
        let frame = FineTuneMenuBarFrameCalculator.frame(
            statusItemFrame: .init(x: 1390, y: 900, width: 24, height: 24),
            contentSize: .init(width: 320, height: 420),
            screenVisibleFrame: .init(x: 0, y: 0, width: 1440, height: 900)
        )

        #expect(frame.origin.x == 1096)
        #expect(frame.maxX == 1416)
    }

    @Test("left-edge overflow clamps inside the visible frame")
    func leftEdgeClamps() {
        let frame = FineTuneMenuBarFrameCalculator.frame(
            statusItemFrame: .init(x: 0, y: 900, width: 24, height: 24),
            contentSize: .init(width: 320, height: 420),
            screenVisibleFrame: .init(x: 0, y: 0, width: 1440, height: 900)
        )

        #expect(frame.origin.x == 2)
    }

    @Test("resizing keeps the popup top edge anchored to the menu bar")
    func resizeKeepsTopAnchor() {
        let statusFrame = CGRect(x: 500, y: 900, width: 24, height: 24)
        let first = FineTuneMenuBarFrameCalculator.frame(
            statusItemFrame: statusFrame,
            contentSize: .init(width: 320, height: 300),
            screenVisibleFrame: nil
        )
        let second = FineTuneMenuBarFrameCalculator.frame(
            statusItemFrame: statusFrame,
            contentSize: .init(width: 320, height: 520),
            screenVisibleFrame: nil
        )

        #expect(first.maxY == second.maxY)
        #expect(first.maxY == statusFrame.minY)
    }
}