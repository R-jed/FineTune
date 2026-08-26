import AppKit
import AudioToolbox
import Testing
@testable import FineTune

@Suite("AudioProcessMonitor app discovery")
struct AudioProcessMonitorTests {
    @Test("Includes user GUI apps and filters background services")
    func userApplicationFilter() {
        let appURL = URL(fileURLWithPath: "/Applications/WeChat.app")
        let serviceURL = URL(fileURLWithPath: "/Applications/WeChat.app/Contents/XPCServices/Helper.xpc")
        let menuBarURL = URL(fileURLWithPath: "/Applications/MenuBarPlayer.app")
        let nestedHelperURL = URL(fileURLWithPath: "/Applications/Browser.app/Contents/Frameworks/Browser Helper.app")
        let systemServiceURL = URL(fileURLWithPath: "/System/Library/CoreServices/ControlCenter.app")

        #expect(AudioProcessMonitor.shouldIncludeUserApplication(
            activationPolicy: .regular,
            isTerminated: false,
            bundleURL: appURL
        ))
        #expect(!AudioProcessMonitor.shouldIncludeUserApplication(
            activationPolicy: .accessory,
            isTerminated: false,
            bundleURL: appURL
        ))
        #expect(AudioProcessMonitor.shouldIncludeUserApplication(
            activationPolicy: .accessory,
            isTerminated: false,
            bundleURL: menuBarURL,
            isAudioActive: true
        ))
        #expect(!AudioProcessMonitor.shouldIncludeUserApplication(
            activationPolicy: .accessory,
            isTerminated: false,
            bundleURL: nestedHelperURL,
            isAudioActive: true
        ))
        #expect(!AudioProcessMonitor.shouldIncludeUserApplication(
            activationPolicy: .accessory,
            isTerminated: false,
            bundleURL: systemServiceURL,
            isAudioActive: true
        ))
        #expect(!AudioProcessMonitor.shouldIncludeUserApplication(
            activationPolicy: .regular,
            isTerminated: false,
            bundleURL: serviceURL
        ))
        #expect(!AudioProcessMonitor.shouldIncludeUserApplication(
            activationPolicy: .regular,
            isTerminated: true,
            bundleURL: appURL
        ))
    }

    @Test("New direct process objects merge into an existing quiet app before full discovery")
    func fastDirectProcessMerge() throws {
        let quiet = AudioApp(
            id: 501,
            processObjectIDs: [],
            name: "Direct App",
            icon: NSImage(),
            bundleID: "com.test.direct",
            isAudioActive: false
        )
        let other = AudioApp(
            id: 777,
            processObjectIDs: [],
            name: "Other App",
            icon: NSImage(),
            bundleID: "com.test.other",
            isAudioActive: false
        )
        let first = AudioObjectID(42)
        let second = AudioObjectID(41)

        let merged = try #require(AudioProcessMonitor.mergeNewDirectProcessObjects(
            into: [quiet, other],
            processIDs: [first, second],
            knownProcessIDs: [],
            pidForProcess: { objectID in
                objectID == first || objectID == second ? quiet.id : nil
            },
            isRunning: { $0 == first }
        ))

        #expect(merged.map(\.id) == [quiet.id, other.id])
        #expect(merged[0].persistenceIdentifier == quiet.persistenceIdentifier)
        #expect(merged[0].processObjectIDs == [second, first])
        #expect(merged[0].isAudioActive)
        #expect(merged[1].processObjectIDs.isEmpty)
    }

    @Test("Helper PID does not bypass responsible-app attribution")
    func helperPIDSkipsFastMerge() {
        let parent = AudioApp(
            id: 501,
            processObjectIDs: [],
            name: "Browser",
            icon: NSImage(),
            bundleID: "com.test.browser",
            isAudioActive: false
        )
        let helperObject = AudioObjectID(90)

        let merged = AudioProcessMonitor.mergeNewDirectProcessObjects(
            into: [parent],
            processIDs: [helperObject],
            knownProcessIDs: [],
            pidForProcess: { _ in 9001 },
            isRunning: { _ in true }
        )

        #expect(merged == nil)
    }

    @Test("Known process objects and helper-backed rows stay on the full refresh path")
    func knownAndHelperBackedObjectsSkipFastMerge() {
        let direct = AudioApp(
            id: 501,
            processObjectIDs: [],
            name: "Direct App",
            icon: NSImage(),
            bundleID: "com.test.direct",
            isAudioActive: false
        )
        let helperBacked = AudioApp(
            id: 777,
            processObjectIDs: [],
            name: "Browser",
            icon: NSImage(),
            bundleID: "com.test.browser",
            isHelperBacked: true,
            isAudioActive: false
        )
        let knownObject = AudioObjectID(41)
        let newHelperObject = AudioObjectID(42)

        let knownResult = AudioProcessMonitor.mergeNewDirectProcessObjects(
            into: [direct],
            processIDs: [knownObject],
            knownProcessIDs: [knownObject],
            pidForProcess: { _ in direct.id },
            isRunning: { _ in true }
        )
        let helperResult = AudioProcessMonitor.mergeNewDirectProcessObjects(
            into: [helperBacked],
            processIDs: [newHelperObject],
            knownProcessIDs: [],
            pidForProcess: { _ in helperBacked.id },
            isRunning: { _ in true }
        )

        #expect(knownResult == nil)
        #expect(helperResult == nil)
    }
}
