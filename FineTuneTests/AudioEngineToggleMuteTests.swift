// FineTuneTests/AudioEngineToggleMuteTests.swift
import Testing
import Foundation
import AppKit
@testable import FineTune

@Suite("AudioEngine.toggleMute")
@MainActor
struct AudioEngineToggleMuteTests {
    @Test("toggleMute flips an unmuted app to muted")
    func toggleUnmutedToMuted() {
        let (engine, app) = makeEngineWithApp(initiallyMuted: false)

        engine.toggleMute(for: app)

        #expect(engine.volumeState.getMute(for: app.id) == true)
    }

    @Test("toggleMute flips a muted app to unmuted")
    func toggleMutedToUnmuted() {
        let (engine, app) = makeEngineWithApp(initiallyMuted: true)

        engine.toggleMute(for: app)

        #expect(engine.volumeState.getMute(for: app.id) == false)
    }

    @Test("toggleMute from muted zero restores the shared fifty-percent slider fallback")
    func toggleMutedZeroRestoresFallback() {
        let (engine, app) = makeEngineWithApp(initiallyMuted: true, initialVolume: 0)

        engine.toggleMute(for: app)

        #expect(engine.volumeState.getMute(for: app.id) == false)
        #expect(engine.currentVolume(for: app) == VolumeMapping.sliderToGain(0.5))
    }

    @Test("toggleMute on zero muted-equivalent output restores fallback without setting mute")
    func toggleZeroUnmutedRestoresFallback() {
        let (engine, app) = makeEngineWithApp(initiallyMuted: false, initialVolume: 0)

        engine.toggleMute(for: app)

        #expect(engine.volumeState.getMute(for: app.id) == false)
        #expect(engine.currentVolume(for: app) == VolumeMapping.sliderToGain(0.5))
    }

    @Test("isAudibleNow returns false when no AudioApp matches the bundle ID")
    func isAudibleNowReturnsFalseForUnknownBundle() {
        let (engine, _) = makeEngineWithApp(initiallyMuted: false)
        #expect(engine.isAudibleNow(bundleID: "com.does.not.exist") == false)
    }

    @Test("isAudibleNow returns false when matched AudioApp has no processObjectIDs")
    func isAudibleNowReturnsFalseWhenNoProcessObjects() {
        let (engine, app) = makeEngineWithApp(initiallyMuted: false)
        #expect(engine.isAudibleNow(bundleID: app.bundleID ?? "") == false)
    }

    private func makeEngineWithApp(
        initiallyMuted: Bool,
        initialVolume: Float = 1.0
    ) -> (AudioEngine, AudioApp) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let settings = SettingsManager(directory: tempDir)
        let deviceMonitor = MockAudioDeviceMonitor()
        let mockVolume = MockDeviceVolumeProviding(deviceMonitor: deviceMonitor)
        let engine = AudioEngine(
            permission: AudioRecordingPermission(),
            settingsManager: settings,
            autoEQProfileManager: AutoEQProfileManager(),
            deviceProvider: deviceMonitor,
            deviceVolumeMonitor: mockVolume,
            startMonitorsAutomatically: false
        )
        let app = AudioApp(
            id: 42424,
            processObjectIDs: [],
            name: "TestApp",
            icon: NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: nil) ?? NSImage(),
            bundleID: "com.test.toggleMute"
        )
        engine.volumeState.setVolume(for: app.id, to: initialVolume, identifier: app.persistenceIdentifier)
        engine.volumeState.setMute(for: app.id, to: initiallyMuted, identifier: app.persistenceIdentifier)
        return (engine, app)
    }
}
