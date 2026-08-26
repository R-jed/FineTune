import Foundation
import Testing
@testable import FineTune

nonisolated final class ControlledSettingsWriter: @unchecked Sendable {
    let firstStarted = DispatchSemaphore(value: 0)
    let releaseFirst = DispatchSemaphore(value: 0)
    let secondStarted = DispatchSemaphore(value: 0)

    private let lock = NSLock()
    private var callCount = 0

    func write(_ data: Data, to url: URL) throws {
        let call = lock.withLock {
            callCount += 1
            return callCount
        }

        if call == 1 {
            firstStarted.signal()
            releaseFirst.wait()
        } else if call == 2 {
            secondStarted.signal()
        }

        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

private nonisolated func waitForSignal(
    _ semaphore: DispatchSemaphore,
    timeout: DispatchTimeInterval
) async -> Bool {
    await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .utility).async {
            continuation.resume(
                returning: semaphore.wait(timeout: .now() + timeout) == .success
            )
        }
    }
}

@Suite("SettingsManager write ordering")
nonisolated struct SettingsManagerWriteOrderingTests {
    @Test("flush waits for an older async write and persists the newest snapshot last")
    func flushKeepsNewestSnapshotLast() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }

        let url = root.appendingPathComponent("settings.json")
        let olderData = Data("older snapshot".utf8)
        let newestData = Data("newest snapshot".utf8)
        let writer = ControlledSettingsWriter()
        let coordinator = SettingsWriteCoordinator(writer: writer.write)

        // Queue the stale write directly. The serialization invariant under test does
        // not depend on SettingsManager's 500 ms UI debounce or MainActor scheduling.
        coordinator.enqueue(olderData, to: url)
        #expect(await waitForSignal(writer.firstStarted, timeout: .seconds(5)))

        let flushStarted = DispatchSemaphore(value: 0)
        let flushTask = Task.detached {
            flushStarted.signal()
            try coordinator.flush(newestData, to: url)
        }
        #expect(await waitForSignal(flushStarted, timeout: .seconds(2)))

        // The first writer is still blocked. A second writer invocation here would
        // prove flush bypassed the serialization point and can overtake it.
        let secondStartedBeforeRelease = await waitForSignal(
            writer.secondStarted,
            timeout: .seconds(1)
        )
        writer.releaseFirst.signal()
        try await flushTask.value

        #expect(!secondStartedBeforeRelease)
        #expect(try Data(contentsOf: url) == newestData)
    }
}