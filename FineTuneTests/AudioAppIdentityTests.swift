import AppKit
import AudioToolbox
import Testing
@testable import FineTune

@Suite("AudioApp runtime identity")
struct AudioAppIdentityTests {
    private func app(pid: pid_t, objectIDs: [AudioObjectID], bundleID: String, active: Bool) -> AudioApp {
        AudioApp(
            id: pid,
            processObjectIDs: objectIDs,
            name: bundleID,
            icon: NSImage(),
            bundleID: bundleID,
            isAudioActive: active
        )
    }

    @Test("PID reuse by a different app is an observable identity change")
    func pidReuseChangesIdentity() {
        let old = app(pid: 42, objectIDs: [1], bundleID: "com.test.old", active: true)
        let replacement = app(pid: 42, objectIDs: [1], bundleID: "com.test.new", active: true)
        #expect(old != replacement)
    }

    @Test("Process object and activity changes are observable")
    func processStateChangesIdentity() {
        let original = app(pid: 42, objectIDs: [1], bundleID: "com.test.app", active: false)
        let changedObjects = app(pid: 42, objectIDs: [2], bundleID: "com.test.app", active: false)
        let active = app(pid: 42, objectIDs: [1], bundleID: "com.test.app", active: true)
        #expect(original != changedObjects)
        #expect(original != active)
    }
}
