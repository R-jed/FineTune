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

        let writer = ControlledSettingsWriter()
        let manager = await MainActor.run {
            SettingsManager(directory: root, writer: writer.write)
        }

        await MainActor.run {
            manager.setVolume(for: "com.test.app", to: 0.25)
        }
        #expect(await waitForSignal(writer.firstStarted, timeout: .seconds(5)))

        await MainActor.run {
            manager.setVolume(for: "com.test.app", to: 0.75)
        }

        let flushStarted = DispatchSemaphore(value: 0)
        let flushTask = Task { @MainActor in
            flushStarted.signal()
            manager.flushSync()
        }
        #expect(await waitForSignal(flushStarted, timeout: .seconds(2)))

        // The first writer is still blocked. A second writer invocation here would
        // prove flushSync bypassed the serialization point and can overtake it.
        let secondStartedBeforeRelease = await waitForSignal(
            writer.secondStarted,
            timeout: .seconds(1)
        )
        writer.releaseFirst.signal()
        await flushTask.value

        #expect(!secondStartedBeforeRelease)

        let persistedVolume = await MainActor.run {
            SettingsManager(directory: root).getVolume(for: "com.test.app")
        }
        #expect(persistedVolume == 0.75)
    }
}
