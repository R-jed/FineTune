// FineTune/Audio/Monitors/AudioProcessMonitor.swift
import AppKit
import AudioToolbox
import os
import UniformTypeIdentifiers

/// Lightweight value for detecting process list changes without comparing icons/names.
private struct AppFingerprint: Hashable {
    let pid: pid_t
    let persistenceIdentifier: String
    let objectIDs: [AudioObjectID]
    let producerBundleIDs: [String]
    let isHelperBacked: Bool
    let isAudioActive: Bool
}

@Observable
@MainActor
final class AudioProcessMonitor: AudioProcessMonitoring {
    private(set) var activeApps: [AudioApp] = []
    var onAppsChanged: (([AudioApp]) -> Void)?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FineTune", category: "AudioProcessMonitor")

    /// Bundle ID prefixes for system daemons that should be filtered from the apps list
    /// These produce system audio (Siri, alerts, notifications) and shouldn't appear as user apps
    private static let systemDaemonPrefixes: [String] = [
        "com.apple.siri",
        "com.apple.Siri",
        "com.apple.assistant",
        "com.apple.audio",
        "com.apple.coreaudio",
        "com.apple.mediaremote",
        "com.apple.accessibility.heard",
        "com.apple.hearingd",
        "com.apple.voicebankingd",
        "com.apple.systemsound",
        "com.apple.FrontBoardServices",
        "com.apple.frontboard",
        "com.apple.springboard",
        "com.apple.notificationcenter",
        "com.apple.NotificationCenter",
        "com.apple.UserNotifications",
        "com.apple.usernotifications",
        "com.apple.SpeechRecognitionCore",
        "com.apple.speech",
        "com.apple.dictation",
        "com.apple.corespeech",
        "com.apple.CoreSpeech",
        "com.apple.VoiceControl",
        "com.apple.voicecontrol",
    ]

    /// Process names for system daemons (fallback when bundle ID is nil or different format)
    private static let systemDaemonNames: [String] = [
        "systemsoundserverd",
        "systemsoundserv",
        "coreaudiod",
        "audiomxd",
        "speechrecognitiond",
        "dictationd",
        "corespeech",
    ]

    /// Returns true if the bundle ID or process name indicates a system daemon that should be filtered
    private func isSystemDaemon(bundleID: String?, name: String) -> Bool {
        // Check bundle ID prefixes
        if let bundleID {
            if Self.systemDaemonPrefixes.contains(where: { bundleID.hasPrefix($0) }) {
                return true
            }
        }

        // Check process name (handles nil bundleID and format variations)
        let lowercaseName = name.lowercased()
        if Self.systemDaemonNames.contains(where: { lowercaseName.hasPrefix($0) }) {
            return true
        }

        return false
    }

    static func shouldIncludeUserApplication(
        activationPolicy: NSApplication.ActivationPolicy,
        isTerminated: Bool,
        bundleURL: URL?,
        hasAudioProcessObject: Bool = false
    ) -> Bool {
        guard !isTerminated, let bundleURL, bundleURL.pathExtension == "app" else { return false }
        if activationPolicy == .regular { return true }

        let path = bundleURL.standardizedFileURL.path
        let appBundleCount = bundleURL.standardizedFileURL.pathComponents
            .filter { $0.hasSuffix(".app") }
            .count
        return hasAudioProcessObject
            && activationPolicy == .accessory
            && !path.hasPrefix("/System/Library/")
            && appBundleCount == 1
    }

    /// Fast path for newly-created HAL process objects. It only attaches objects whose PID
    /// already matches a known direct user-app row. Helper/XPC objects deliberately miss this
    /// path and continue through the full responsibility-resolution refresh below.
    static func mergeNewDirectProcessObjects(
        into apps: [AudioApp],
        processIDs: [AudioObjectID],
        knownProcessIDs: Set<AudioObjectID>,
        pidForProcess: (AudioObjectID) -> pid_t?,
        isRunning: (AudioObjectID) -> Bool,
        producerBundleIDForProcess: (AudioObjectID) -> String? = { _ in nil }
    ) -> [AudioApp]? {
        let added = Set(processIDs).subtracting(knownProcessIDs)
        guard !added.isEmpty else { return nil }

        var appsByPID = Dictionary(
            apps.map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        var changed = false

        for objectID in added.sorted() {
            guard let pid = pidForProcess(objectID),
                  let existing = appsByPID[pid],
                  !existing.isHelperBacked,
                  !existing.processObjectIDs.contains(objectID) else { continue }

            var mergedIDs = existing.processObjectIDs
            mergedIDs.append(objectID)
            mergedIDs.sort()

            var producerBundleIDs = Set(existing.producerBundleIDs)
            if let producerBundleID = producerBundleIDForProcess(objectID), !producerBundleID.isEmpty {
                producerBundleIDs.insert(producerBundleID)
            }

            appsByPID[pid] = AudioApp(
                id: existing.id,
                processObjectIDs: mergedIDs,
                name: existing.name,
                icon: existing.icon,
                bundleID: existing.bundleID,
                producerBundleIDs: Array(producerBundleIDs).sorted(),
                isHelperBacked: false,
                isAudioActive: existing.isAudioActive || isRunning(objectID)
            )
            changed = true
        }

        guard changed else { return nil }
        return apps.map { appsByPID[$0.id] ?? $0 }
    }

    // Property listeners
    private var processListListenerBlock: AudioObjectPropertyListenerBlock?
    private var processListenerBlocks: [AudioObjectID: AudioObjectPropertyListenerBlock] = [:]
    private var monitoredProcesses: Set<AudioObjectID> = []
    private var periodicRefreshTask: Task<Void, Never>?
    private var workspaceObserverTokens: [NSObjectProtocol] = []

    private var processListAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyProcessObjectList,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    /// Function type for the private responsibility API
    private typealias ResponsibilityFunc = @convention(c) (pid_t) -> pid_t

    /// Gets the "responsible" PID for a process using Apple's private API.
    /// This is what Activity Monitor uses to show the correct parent for XPC services.
    private func getResponsiblePID(for pid: pid_t) -> pid_t? {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -1), "responsibility_get_pid_responsible_for_pid") else {
            return nil
        }
        let responsiblePID = unsafeBitCast(symbol, to: ResponsibilityFunc.self)(pid)
        return responsiblePID > 0 && responsiblePID != pid ? responsiblePID : nil
    }

    /// Finds the responsible application for a helper/XPC process.
    /// Uses Apple's responsibility API first, falls back to process tree walking.
    private func findResponsibleApp(
        for pid: pid_t,
        in runningAppsByPID: [pid_t: NSRunningApplication],
        hasAudioProcessObject: Bool
    ) -> NSRunningApplication? {
        // First try Apple's responsibility API (works for XPC services like Safari's WebKit processes)
        if let responsiblePID = getResponsiblePID(for: pid),
           let app = runningAppsByPID[responsiblePID],
           Self.shouldIncludeUserApplication(
               activationPolicy: app.activationPolicy,
               isTerminated: app.isTerminated,
               bundleURL: app.bundleURL,
               hasAudioProcessObject: hasAudioProcessObject
           ) {
            return app
        }

        // Fall back to walking up the process tree (works for Chrome/Brave helpers)
        var currentPID = pid
        var visited = Set<pid_t>()

        while currentPID > 1 && !visited.contains(currentPID) {
            visited.insert(currentPID)

            // Check if this PID is a proper app bundle (.app, not .xpc service)
            if let app = runningAppsByPID[currentPID],
               Self.shouldIncludeUserApplication(
                   activationPolicy: app.activationPolicy,
                   isTerminated: app.isTerminated,
                   bundleURL: app.bundleURL,
                   hasAudioProcessObject: hasAudioProcessObject
               ) {
                return app
            }

            // Get parent PID using sysctl
            var info = kinfo_proc()
            var size = MemoryLayout<kinfo_proc>.size
            var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, currentPID]

            guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { break }

            let parentPID = info.kp_eproc.e_ppid
            if parentPID == currentPID { break }
            currentPID = parentPID
        }

        return nil
    }

    func start() {
        guard processListListenerBlock == nil else { return }

        logger.debug("Starting audio process monitor")

        // This listener is explicitly delivered on DispatchQueue.main. Enter the MainActor
        // synchronously so a new process object can reach AudioEngine before a second queue hop.
        processListListenerBlock = { [weak self] _, _ in
            let notificationUptime = ProcessInfo.processInfo.systemUptime
            MainActor.assumeIsolated {
                self?.refresh(processListNotificationUptime: notificationUptime)
            }
        }

        let status = AudioObjectAddPropertyListenerBlock(
            .system,
            &processListAddress,
            .main,
            processListListenerBlock!
        )

        if status != noErr {
            logger.error("Failed to add process list listener: \(status)")
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceObserverTokens = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
        ].map { name in
            workspaceCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refresh()
                }
            }
        }

        // Initial refresh
        refresh()

        // Periodic refresh as safety net — CoreAudio property listeners can miss
        // notifications during rapid process lifecycle changes (quit + relaunch).
        startPeriodicRefresh()
    }

    func stop() {
        logger.debug("Stopping audio process monitor")

        periodicRefreshTask?.cancel()
        periodicRefreshTask = nil

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceObserverTokens.forEach(workspaceCenter.removeObserver)
        workspaceObserverTokens.removeAll()

        // Remove process list listener
        if let block = processListListenerBlock {
            AudioObjectRemovePropertyListenerBlock(.system, &processListAddress, .main, block)
            processListListenerBlock = nil
        }

        // Remove all per-process listeners
        removeAllProcessListeners()
    }

    private func startPeriodicRefresh() {
        periodicRefreshTask?.cancel()
        periodicRefreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                // 10s is sufficient as a safety net — HAL listeners handle most changes.
                // Lower intervals waste CPU at idle (#176).
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled, let self else { return }
                self.refresh()
            }
        }
    }

    private func refresh(processListNotificationUptime: TimeInterval? = nil) {
        do {
            let processIDs = try AudioObjectID.readProcessList()

            // Time-critical path for macOS versions where bundle-targeted prearming is unavailable.
            // Existing quiet GUI apps are already known by PID, so a newly-created direct HAL
            // process object can be published to AudioEngine before NSWorkspace/helper discovery.
            if let fastApps = Self.mergeNewDirectProcessObjects(
                into: activeApps,
                processIDs: processIDs,
                knownProcessIDs: monitoredProcesses,
                pidForProcess: { try? $0.readProcessPID() },
                isRunning: { $0.readProcessIsRunning() },
                producerBundleIDForProcess: { $0.readProcessBundleID() }
            ) {
                activeApps = fastApps
                onAppsChanged?(activeApps)

                if let started = processListNotificationUptime {
                    let elapsedMs = (ProcessInfo.processInfo.systemUptime - started) * 1000
                    logger.debug("Fast process-object provisioning callback completed in \(elapsedMs, format: .fixed(precision: 2)) ms")
                }
            }

            let runningApps = NSWorkspace.shared.runningApplications
            let runningAppsByPID = Dictionary(
                runningApps.map { ($0.processIdentifier, $0) },
                uniquingKeysWith: { _, latest in latest }
            )
            let myPID = ProcessInfo.processInfo.processIdentifier
            let rememberedProducerBundleIDs = Dictionary(
                activeApps.map { ($0.persistenceIdentifier, Set($0.producerBundleIDs)) },
                uniquingKeysWith: { $0.union($1) }
            )

            var appsByPID: [pid_t: AudioApp] = [:]

            for app in runningApps where app.processIdentifier != myPID {
                guard Self.shouldIncludeUserApplication(
                    activationPolicy: app.activationPolicy,
                    isTerminated: app.isTerminated,
                    bundleURL: app.bundleURL
                ), let name = app.localizedName else { continue }

                let persistenceIdentifier = app.bundleIdentifier ?? "name:\(name)"
                appsByPID[app.processIdentifier] = AudioApp(
                    id: app.processIdentifier,
                    processObjectIDs: [],
                    name: name,
                    icon: app.icon ?? NSWorkspace.shared.icon(for: .applicationBundle),
                    bundleID: app.bundleIdentifier,
                    producerBundleIDs: Array(rememberedProducerBundleIDs[persistenceIdentifier] ?? []).sorted(),
                    isAudioActive: false
                )
            }

            for objectID in processIDs {
                guard let pid = try? objectID.readProcessPID(), pid != myPID else { continue }
                let isAudioActive = objectID.readProcessIsRunning()
                let producerBundleID = objectID.readProcessBundleID()

                // A Core Audio process object is itself enough evidence to keep a top-level
                // accessory app routable, even while isRunning is false. This lets FineTune
                // arm the tap before a short notification sound starts without listing every
                // quiet background accessory app in NSWorkspace.
                let directApp = runningAppsByPID[pid]
                let directIsUserApp = directApp.map {
                    Self.shouldIncludeUserApplication(
                        activationPolicy: $0.activationPolicy,
                        isTerminated: $0.isTerminated,
                        bundleURL: $0.bundleURL,
                        hasAudioProcessObject: true
                    )
                } ?? false
                let resolvedApp = directIsUserApp
                    ? directApp
                    : findResponsibleApp(for: pid, in: runningAppsByPID, hasAudioProcessObject: true)
                let parentPID = resolvedApp?.processIdentifier ?? pid
                let isHelper = parentPID != pid

                // Use resolved app's info, fall back to the Core Audio producer identity.
                let name = resolvedApp?.localizedName
                    ?? producerBundleID?.components(separatedBy: ".").last
                    ?? "Unknown"
                let icon = resolvedApp?.icon
                    ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)
                    ?? NSImage()
                let bundleID = resolvedApp?.bundleIdentifier ?? producerBundleID

                guard let resolvedApp,
                      Self.shouldIncludeUserApplication(
                          activationPolicy: resolvedApp.activationPolicy,
                          isTerminated: resolvedApp.isTerminated,
                          bundleURL: resolvedApp.bundleURL,
                          hasAudioProcessObject: true
                      ) else { continue }

                // Skip system daemons (siri, coreaudio, etc.) - they shouldn't appear as user apps
                if isSystemDaemon(bundleID: bundleID, name: name) { continue }

                // Merge helper process objectIDs and producer identities into the parent app entry.
                if let existing = appsByPID[parentPID] {
                    if !existing.processObjectIDs.contains(objectID) {
                        var mergedIDs = existing.processObjectIDs
                        mergedIDs.append(objectID)
                        mergedIDs.sort()

                        var producerBundleIDs = Set(existing.producerBundleIDs)
                        if let producerBundleID, !producerBundleID.isEmpty {
                            producerBundleIDs.insert(producerBundleID)
                        }

                        appsByPID[parentPID] = AudioApp(
                            id: existing.id,
                            processObjectIDs: mergedIDs,
                            name: existing.name,
                            icon: existing.icon,
                            bundleID: existing.bundleID,
                            producerBundleIDs: Array(producerBundleIDs).sorted(),
                            isHelperBacked: existing.isHelperBacked || isHelper,
                            isAudioActive: existing.isAudioActive || isAudioActive
                        )
                    }
                } else {
                    let persistenceIdentifier = bundleID ?? "name:\(name)"
                    var producerBundleIDs = rememberedProducerBundleIDs[persistenceIdentifier] ?? []
                    if let producerBundleID, !producerBundleID.isEmpty {
                        producerBundleIDs.insert(producerBundleID)
                    }
                    appsByPID[parentPID] = AudioApp(
                        id: parentPID,
                        processObjectIDs: [objectID],
                        name: name,
                        icon: icon,
                        bundleID: bundleID,
                        producerBundleIDs: Array(producerBundleIDs).sorted(),
                        isHelperBacked: isHelper,
                        isAudioActive: isAudioActive
                    )
                }
            }

            // Update per-process listeners
            updateProcessListeners(for: processIDs)

            let appsByIdentifier = Dictionary(
                appsByPID.values.map { ($0.persistenceIdentifier, $0) },
                uniquingKeysWith: { $0.merging($1) }
            )
            let sorted = appsByIdentifier.values.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

            // Only fire callback if the app list actually changed (avoids churn from periodic refresh)
            let oldSet = Set(activeApps.map {
                AppFingerprint(
                    pid: $0.id,
                    persistenceIdentifier: $0.persistenceIdentifier,
                    objectIDs: $0.processObjectIDs,
                    producerBundleIDs: $0.producerBundleIDs,
                    isHelperBacked: $0.isHelperBacked,
                    isAudioActive: $0.isAudioActive
                )
            })
            let newSet = Set(sorted.map {
                AppFingerprint(
                    pid: $0.id,
                    persistenceIdentifier: $0.persistenceIdentifier,
                    objectIDs: $0.processObjectIDs,
                    producerBundleIDs: $0.producerBundleIDs,
                    isHelperBacked: $0.isHelperBacked,
                    isAudioActive: $0.isAudioActive
                )
            })

            activeApps = sorted
            if oldSet != newSet {
                onAppsChanged?(activeApps)
            }

        } catch {
            logger.error("Failed to refresh process list: \(error.localizedDescription)")
        }
    }

    private func updateProcessListeners(for processIDs: [AudioObjectID]) {
        let currentSet = Set(processIDs)

        // Remove listeners for processes that are gone
        let removed = monitoredProcesses.subtracting(currentSet)
        for objectID in removed {
            removeProcessListener(for: objectID)
        }

        // Add listeners for new processes
        let added = currentSet.subtracting(monitoredProcesses)
        for objectID in added {
            addProcessListener(for: objectID)
        }

        monitoredProcesses = currentSet
    }

    private func addProcessListener(for objectID: AudioObjectID) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunning,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }

        let status = AudioObjectAddPropertyListenerBlock(objectID, &address, .main, block)

        if status == noErr {
            processListenerBlocks[objectID] = block
        } else {
            logger.warning("Failed to add isRunning listener for \(objectID): \(status)")
        }
    }

    private func removeProcessListener(for objectID: AudioObjectID) {
        guard let block = processListenerBlocks.removeValue(forKey: objectID) else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunning,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectRemovePropertyListenerBlock(objectID, &address, .main, block)
        // Tolerate kAudioHardwareBadObjectError (-66680): process object already destroyed
        if status != noErr && status != OSStatus(kAudioHardwareBadObjectError) {
            logger.warning("Failed to remove isRunning listener for \(objectID): \(status)")
        }
    }

    private func removeAllProcessListeners() {
        for objectID in monitoredProcesses {
            removeProcessListener(for: objectID)
        }
        monitoredProcesses.removeAll()
        processListenerBlocks.removeAll()
    }

}
