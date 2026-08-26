import Foundation
import Testing
@testable import FineTune

@Suite("VolumeState app identity")
@MainActor
struct VolumeStateIdentityTests {
    @Test("Reused PID starts with clean transient state for the new app identity")
    func reusedPIDResetsTransientState() {
        let manager = SettingsManager(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
        )
        let state = VolumeState(settingsManager: manager)
        let pid: pid_t = 4242
        let oldID = "com.test.old"
        let newID = "com.test.new"

        state.setVolume(for: pid, to: 0.25, identifier: oldID)
        state.setMute(for: pid, to: true, identifier: oldID)
        state.setBoost(for: pid, to: .x4, identifier: oldID)
        state.setDeviceSelectionMode(for: pid, to: .multi, identifier: oldID)
        state.setSelectedDeviceUIDs(for: pid, to: ["old-a", "old-b"], identifier: oldID)
        manager.setVolume(for: newID, to: 0.8)

        #expect(state.loadSavedVolume(for: pid, identifier: newID) == 0.8)
        #expect(state.getMute(for: pid) == false)
        #expect(state.getBoost(for: pid) == .x1)
        #expect(state.getDeviceSelectionMode(for: pid) == .single)
        #expect(state.getSelectedDeviceUIDs(for: pid).isEmpty)
    }
}
