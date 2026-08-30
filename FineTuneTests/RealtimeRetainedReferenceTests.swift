// FineTuneTests/RealtimeRetainedReferenceTests.swift

import Foundation
import Testing
@testable import FineTune

@Suite("Realtime retained reference")
struct RealtimeRetainedReferenceTests {
    nonisolated final class Probe: @unchecked Sendable {
        let id: Int
        private let onDeinit: @Sendable () -> Void

        init(id: Int, onDeinit: @escaping @Sendable () -> Void = {}) {
            self.id = id
            self.onDeinit = onDeinit
        }

        deinit {
            onDeinit()
        }
    }

    @Test("replacement releases the old value only from the retirement path after readers exit")
    func replacementWaitsForActiveReader() {
        let retirementQueue = DispatchQueue(label: "RealtimeRetainedReferenceTests.retirement")
        let oldReleased = DispatchSemaphore(value: 0)
        let readerEntered = DispatchSemaphore(value: 0)
        let readerSawOld = DispatchSemaphore(value: 0)
        let allowReaderExit = DispatchSemaphore(value: 0)
        let readerFinished = DispatchSemaphore(value: 0)

        var old: Probe? = Probe(id: 1) {
            oldReleased.signal()
        }
        let reference = RealtimeRetainedReference(old, retirementQueue: retirementQueue)
        old = nil

        DispatchQueue.global(qos: .userInitiated).async {
            reference.withBorrowedValue { unmanaged in
                if unmanaged?.takeUnretainedValue().id == 1 {
                    readerSawOld.signal()
                }
                readerEntered.signal()
                _ = allowReaderExit.wait(timeout: .now() + 2)
            }
            readerFinished.signal()
        }

        #expect(readerEntered.wait(timeout: .now() + 1) == .success)
        #expect(readerSawOld.wait(timeout: .now()) == .success)

        // Freeze retirement so the test can distinguish reader teardown from the
        // intended off-RT release path deterministically.
        retirementQueue.suspend()
        let replacement = Probe(id: 2)
        reference.replace(with: replacement)

        #expect(oldReleased.wait(timeout: .now() + 0.05) == .timedOut)

        allowReaderExit.signal()
        #expect(readerFinished.wait(timeout: .now() + 1) == .success)

        // Even after the realtime reader has fully returned, the old object must
        // remain alive while retirement is suspended. A release here would mean
        // the reader itself can become the final ARC owner again.
        #expect(oldReleased.wait(timeout: .now() + 0.05) == .timedOut)

        retirementQueue.resume()
        retirementQueue.sync {}
        #expect(oldReleased.wait(timeout: .now() + 1) == .success)
    }

    @Test("republishing the same object retires the replaced storage retain")
    func sameObjectPublicationDoesNotLeakStorageOwnership() {
        let retirementQueue = DispatchQueue(label: "RealtimeRetainedReferenceTests.same-object")
        let released = DispatchSemaphore(value: 0)

        var probe: Probe? = Probe(id: 7) {
            released.signal()
        }
        var reference: RealtimeRetainedReference<Probe>? = RealtimeRetainedReference(
            probe,
            retirementQueue: retirementQueue
        )

        reference?.replace(with: probe)
        retirementQueue.sync {}
        probe = nil

        var observedID: Int?
        reference?.withBorrowedValue { unmanaged in
            observedID = unmanaged?.takeUnretainedValue().id
        }
        #expect(observedID == 7)

        reference = nil
        #expect(released.wait(timeout: .now() + 1) == .success)
    }
}
