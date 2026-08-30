// FineTuneTests/RealtimeQuiescenceGateTests.swift

import Foundation
import Testing
@testable import FineTune

@Suite("RealtimeQuiescenceGate")
struct RealtimeQuiescenceGateTests {

    @Test("waitForReaders blocks until an active reader leaves")
    func waitsForActiveReader() {
        let gate = RealtimeQuiescenceGate()
        gate.enterRead()
        let checkpoint = gate.checkpoint()

        let waiterStarted = DispatchSemaphore(value: 0)
        let waiterFinished = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .userInitiated).async {
            waiterStarted.signal()
            gate.waitForReaders(after: checkpoint)
            waiterFinished.signal()
        }

        #expect(waiterStarted.wait(timeout: .now() + 1) == .success)
        #expect(waiterFinished.wait(timeout: .now() + 0.05) == .timedOut)

        gate.leaveRead()

        #expect(waiterFinished.wait(timeout: .now() + 1) == .success)
    }

    @Test("only the last concurrent reader advances quiescence")
    func lastReaderDefinesQuiescence() {
        let gate = RealtimeQuiescenceGate()
        gate.enterRead()
        gate.enterRead()
        let checkpoint = gate.checkpoint()

        let waiterStarted = DispatchSemaphore(value: 0)
        let waiterFinished = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .userInitiated).async {
            waiterStarted.signal()
            gate.waitForReaders(after: checkpoint)
            waiterFinished.signal()
        }

        #expect(waiterStarted.wait(timeout: .now() + 1) == .success)
        gate.leaveRead()
        #expect(waiterFinished.wait(timeout: .now() + 0.05) == .timedOut)

        gate.leaveRead()
        #expect(waiterFinished.wait(timeout: .now() + 1) == .success)
    }

    @Test("a later reader cannot invalidate an already observed quiescent point")
    func laterReaderDoesNotBlockRetiredGeneration() {
        let gate = RealtimeQuiescenceGate()

        gate.enterRead()
        let checkpoint = gate.checkpoint()
        gate.leaveRead()

        // This reader starts after the checkpoint's readers have already reached zero.
        // A retired setup from that checkpoint is now safe to reclaim even while this
        // later reader is active, because it can only observe the replacement setup.
        gate.enterRead()
        gate.waitForReaders(after: checkpoint)
        gate.leaveRead()
    }
}
