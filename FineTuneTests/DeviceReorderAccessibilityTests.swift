import Testing
@testable import FineTune

@Suite("U5 device reorder accessibility")
struct DeviceReorderAccessibilityTests {
    @Test("first device exposes only move down")
    func firstDeviceBoundary() {
        #expect(DeviceReorderAccessibility.targetIndex(currentIndex: 0, direction: -1, count: 3) == nil)
        #expect(DeviceReorderAccessibility.targetIndex(currentIndex: 0, direction: 1, count: 3) == 1)
    }

    @Test("middle device exposes both adjacent moves")
    func middleDevice() {
        #expect(DeviceReorderAccessibility.targetIndex(currentIndex: 1, direction: -1, count: 3) == 0)
        #expect(DeviceReorderAccessibility.targetIndex(currentIndex: 1, direction: 1, count: 3) == 2)
    }

    @Test("last device exposes only move up")
    func lastDeviceBoundary() {
        #expect(DeviceReorderAccessibility.targetIndex(currentIndex: 2, direction: -1, count: 3) == 1)
        #expect(DeviceReorderAccessibility.targetIndex(currentIndex: 2, direction: 1, count: 3) == nil)
    }

    @Test("unsupported directions fail closed")
    func unsupportedDirection() {
        #expect(DeviceReorderAccessibility.targetIndex(currentIndex: 1, direction: 0, count: 3) == nil)
        #expect(DeviceReorderAccessibility.targetIndex(currentIndex: 1, direction: 2, count: 3) == nil)
    }

    @Test("device reorder uses one insertion rule for forward and backward moves")
    func reorderedIdentifiers() {
        let order = ["A", "B", "C", "D"]

        #expect(DeviceReorderAccessibility.reorderedIdentifiers(
            order,
            moving: "A",
            to: 2
        ) == ["B", "C", "A", "D"])
        #expect(DeviceReorderAccessibility.reorderedIdentifiers(
            order,
            moving: "D",
            to: 1
        ) == ["A", "D", "B", "C"])
    }

    @Test("device reorder rejects self, missing source, and invalid target")
    func invalidReorderTargetsFailClosed() {
        let order = ["A", "B", "C"]

        #expect(DeviceReorderAccessibility.reorderedIdentifiers(order, moving: "B", to: 1) == nil)
        #expect(DeviceReorderAccessibility.reorderedIdentifiers(order, moving: "missing", to: 1) == nil)
        #expect(DeviceReorderAccessibility.reorderedIdentifiers(order, moving: "A", to: 3) == nil)
    }
}
