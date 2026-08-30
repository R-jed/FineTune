// FineTune/Audio/Engine/RealtimeRetainedReference.swift

import Foundation
import Synchronization

/// Publishes one class reference to realtime readers and retires replaced values
/// only after every reader that could have observed the old pointer reaches a
/// quiescent point.
///
/// The realtime read path registers the reader, loads an unmanaged pointer, and
/// keeps that reader registered until the nonescaping body returns. Replacement
/// and retirement run off the HAL callback and may wait for reader quiescence.
nonisolated final class RealtimeRetainedReference<Value: AnyObject>: @unchecked Sendable {
    private struct RetiredPointer: @unchecked Sendable {
        let raw: OpaquePointer
    }

    private let storage = Atomic<OpaquePointer?>(nil)
    private let quiescence = RealtimeQuiescenceGate()
    private let retirementQueue: DispatchQueue

    init(
        _ value: Value? = nil,
        retirementQueue: DispatchQueue = .global(qos: .utility)
    ) {
        self.retirementQueue = retirementQueue
        if let value {
            storage.store(Self.retain(value), ordering: .sequentiallyConsistent)
        }
    }

    deinit {
        guard let old = storage.exchange(nil, ordering: .sequentiallyConsistent) else { return }
        let checkpoint = quiescence.checkpoint()
        quiescence.waitForReaders(after: checkpoint)
        Self.release(old)
    }

    /// Runs a nonescaping body while the current pointer is protected from retirement.
    /// The unmanaged handle must not escape the body.
    @inline(__always)
    func withBorrowedValue(_ body: (Unmanaged<Value>?) -> Void) {
        quiescence.enterRead()
        defer { quiescence.leaveRead() }

        let raw = storage.load(ordering: .sequentiallyConsistent)
        if let raw {
            body(Unmanaged<Value>.fromOpaque(UnsafeRawPointer(raw)))
        } else {
            body(nil)
        }
    }

    /// Publishes the replacement immediately. Any prior retained value is released
    /// on the retirement queue only after a real reader-quiescent point.
    func replace(with value: Value?) {
        let replacement = value.map(Self.retain)
        guard let old = storage.exchange(replacement, ordering: .sequentiallyConsistent) else { return }

        let checkpoint = quiescence.checkpoint()
        let gate = quiescence
        let retired = RetiredPointer(raw: old)
        retirementQueue.async {
            gate.waitForReaders(after: checkpoint)
            Self.release(retired.raw)
        }
    }

    private static func retain(_ value: Value) -> OpaquePointer {
        OpaquePointer(Unmanaged.passRetained(value).toOpaque())
    }

    private static func release(_ raw: OpaquePointer) {
        Unmanaged<Value>.fromOpaque(UnsafeRawPointer(raw)).release()
    }
}
