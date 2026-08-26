from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text()


def write(path: str, text: str) -> None:
    Path(path).write_text(text)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)


path = "FineTune/Settings/SettingsManager.swift"
s = read(path)
s = replace_once(
    s,
    """// MARK: - Settings Manager

@Observable
""",
    """// MARK: - Settings Manager

nonisolated final class SettingsWriteCoordinator: @unchecked Sendable {
    typealias Writer = @Sendable (Data, URL) throws -> Void

    private let queue = DispatchQueue(label: "com.finetune.settings-write", qos: .utility)
    private let writer: Writer

    init(writer: @escaping Writer) {
        self.writer = writer
    }

    func enqueue(_ data: Data, to url: URL) {
        let writer = self.writer
        queue.async {
            try? writer(data, url)
        }
    }

    func flush(_ data: Data, to url: URL) throws {
        let writer = self.writer
        try queue.sync {
            try writer(data, url)
        }
    }
}

@Observable
""",
    "write coordinator",
)
s = replace_once(
    s,
    """    private var saveTask: Task<Void, Never>?
    private let settingsURL: URL
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FineTune", category: "SettingsManager")
""",
    """    private var saveTask: Task<Void, Never>?
    private let settingsURL: URL
    private let writeCoordinator: SettingsWriteCoordinator
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FineTune", category: "SettingsManager")
""",
    "coordinator property",
)
s = replace_once(
    s,
    """    init(directory: URL? = nil) {
        let baseDir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("FineTune")
        self.settingsURL = baseDir.appendingPathComponent("settings.json")
        self.settings = Settings()
        loadFromDisk()
    }
""",
    """    init(
        directory: URL? = nil,
        writer: @escaping SettingsWriteCoordinator.Writer = SettingsManager.writeData
    ) {
        let baseDir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("FineTune")
        self.settingsURL = baseDir.appendingPathComponent("settings.json")
        self.writeCoordinator = SettingsWriteCoordinator(writer: writer)
        self.settings = Settings()
        loadFromDisk()
    }
""",
    "coordinator initialization",
)
s = replace_once(
    s,
    """    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            let snapshot = settings
            let url = settingsURL
            let data = try? JSONEncoder().encode(snapshot)
            guard let data else { return }
            Task.detached(priority: .utility) {
                do {
                    try Self.writeData(data, to: url)
                } catch {
                    // Avoid actor hops/logging on audio-critical paths; failures are
                    // non-fatal and will retry on the next settings mutation.
                }
            }
        }
    }

    /// Immediately writes pending changes to disk.
    /// Call this on app termination to prevent data loss.
    func flushSync() {
        saveTask?.cancel()
        saveTask = nil
        writeToDisk()
    }

    private func writeToDisk() {
        do {
            let data = try JSONEncoder().encode(settings)
            try Self.writeData(data, to: settingsURL)

            logger.debug("Saved settings")
        } catch {
            logger.error("Failed to save settings: \\(error.localizedDescription)")
        }
    }
""",
    """    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            let snapshot = settings
            let url = settingsURL
            let data = try? JSONEncoder().encode(snapshot)
            guard let data else { return }
            writeCoordinator.enqueue(data, to: url)
        }
    }

    /// Immediately writes pending changes to disk after every older queued write.
    /// Call this on app termination to prevent stale asynchronous saves from winning.
    func flushSync() {
        saveTask?.cancel()
        saveTask = nil
        writeToDisk()
    }

    private func writeToDisk() {
        do {
            let data = try JSONEncoder().encode(settings)
            try writeCoordinator.flush(data, to: settingsURL)

            logger.debug("Saved settings")
        } catch {
            logger.error("Failed to save settings: \\(error.localizedDescription)")
        }
    }
""",
    "serialized save paths",
)
write(path, s)


test_path = Path("FineTuneTests/SettingsManagerWriteOrderingTests.swift")
if test_path.exists():
    raise SystemExit(f"{test_path}: expected file to be absent")
test_path.write_text(
    r'''import Foundation
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
'''
)
