// FineTune/Views/MenuBarPopupView.swift
import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarPopupView: View {
    @Bindable var audioEngine: AudioEngine
    @Bindable var deviceVolumeMonitor: DeviceVolumeMonitor
    @ObservedObject var updateManager: UpdateManager

    let permission: AudioRecordingPermission

    /// Accessibility trust state — forwarded to the Settings window for the
    /// media-keys section. Bindable so live re-renders occur when trust flips.
    @Bindable var accessibility: AccessibilityPermissionService

    /// Transient status (offline, suppressionDegraded) for the media-keys banner.
    @Bindable var mediaKeyStatus: MediaKeyStatus

    /// Shared popup visibility flag — mirrored to this service so `MediaKeyMonitor`
    /// can skip HUD display while the popup is the "HUD".
    @Bindable var popupVisibility: PopupVisibilityService

    /// Preview HUD button hook in Settings.
    let hudController: HUDWindowController

    /// Needed so the popup can reconcile the tap state when the user toggles
    /// `mediaKeyControlEnabled` inside Settings. Trust-flip reconciliation is
    /// handled globally via `AccessibilityPermissionService.onTrustChanged`
    /// wired in `FineTuneApp.init`.
    let mediaKeyMonitor: MediaKeyMonitor

    /// Memoized sorted output devices - only recomputed when device list or default changes
    @State private var sortedDevices: [AudioDevice] = []

    /// Memoized sorted input devices
    @State private var sortedInputDevices: [AudioDevice] = []

    /// Single source of truth for popup page depth and audio direction.
    @State private var popupPage: PopupPage = .main(.output)

    /// Owns the currently expanded structural surface. App EQ and output-device
    /// detail are mutually exclusive and can retarget without a timing lock.
    @State private var expansionState = PopupExpansionState()

    /// Track popup visibility to pause VU meter polling when hidden
    @State private var isPopupVisible = true

    /// Localizable error shown when AutoEQ profile import fails.
    @State private var autoEQImportError: LocalizedStringResource?
    /// Task that auto-clears the import error after 3 seconds
    @State private var importErrorClearTask: Task<Void, Never>?

    /// Localizable error shown when one or more selected bundles are invalid.
    @State private var appSelectionError: LocalizedStringResource?

    /// Memoized paired Bluetooth devices
    @State private var pairedDevices: [PairedBluetoothDevice] = []

    /// Whether Bluetooth hardware is powered on
    @State private var isBluetoothOn = false

    /// Editable copy of device order for drag-and-drop reordering
    @State private var editableDeviceOrder: [AudioDevice] = []

    /// Continuous pointer-reorder state for device priority rows. Device order
    /// is already local while management is open, so crossings mutate only
    /// `editableDeviceOrder` and persistence remains deferred to edit exit.
    @State private var deviceReorderDragState = ContinuousReorderDragState()

    /// Continuous pointer-reorder state for primary App rows. Unlike the old
    /// implementation, crossings mutate only a transient presentation order;
    /// the final App order is committed once when the gesture ends.
    @State private var appReorderDragState = ContinuousReorderDragState()
    @State private var appReorderInitialOrder: [String]? = nil
    @State private var transientAppOrder: [String]? = nil
    @State private var transientPinnedAppIDs: Set<String>? = nil

    @State private var navModel = PopupKeyboardNavModel()
    /// Logical keyboard-nav selection. Plain @State (not @FocusState) so reads
    /// and writes are synchronous within a single event handler — using
    /// @FocusState here raced with SwiftUI's auto-focus-on-key-window claim
    /// (WWDC23 "SwiftUI cookbook for focus" calls this anti-pattern). A single
    /// focusable anchor on the popup body root receives key events; rows
    /// render their selection state purely from this @State value.
    @State private var selectedRow: PopupKeyboardNavModel.RowID? = nil
    /// True once the user presses any nav-vocabulary key. Gates the row-highlight
    /// visual so a fresh popup opens clean even though `selectedRow` may be set.
    @State private var hasKeyboardEngaged: Bool = false
    /// `.onKeyPress` only fires when the modifier-owning view (or a focused
    /// descendant) has focus, so the body root holds a focus anchor.
    @FocusState private var anchorFocused: Bool
    /// Owns keyboard percentage entry (buffer + commit/restore signals), broadcast to
    /// rows via the environment. First responder stays on the nav anchor throughout.
    @State private var textEntry = PopupTextEntryCoordinator()

    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    // MARK: - Resolved Dimensions

    private var popupDimensions: PopupDimensions {
        audioEngine.settingsManager.appSettings.popupSize.dimensions
    }

    private var structuralExpansionAnimation: Animation? {
        accessibilityReduceMotion ? nil : DesignTokens.Animation.structural
    }

    /// Overlay scroll bars live inside the ScrollView bounds on macOS. Reserve
    /// a real content gutter so trailing row controls never sit underneath the
    /// thumb in compact or comfortable layouts.
    private static let scrollbarContentGutter = DesignTokens.Spacing.xl

    private var showingInputDevices: Bool {
        popupPage.direction.isInput
    }

    private var isEditingDevicePriority: Bool {
        popupPage.isManagement
    }

    private var devicePriorityEditMode: PopupAudioDirection? {
        popupPage.isManagement ? popupPage.direction : nil
    }

    private var popupLayout: some View {
        ScrollViewReader { proxy in
            PopupShell(
                direction: popupPage.direction,
                isManaging: isEditingDevicePriority,
                width: popupDimensions.width,
                contentPadding: popupDimensions.contentPadding,
                onSelectDirection: { direction in
                    selectDeviceTab(showInput: direction.isInput)
                },
                onToggleManagement: toggleDevicePriorityEdit,
                onOpenSettings: openSettingsWindow
            ) {
                // Match the original FineTune/FluidMenuBarExtra sizing model:
                // one bounded content scroll view, with Output/Input swapping in
                // place rather than creating a second page-transition geometry owner.
                ScrollView {
                    mainContent
                }
                .scrollIndicators(.never)
                .frame(maxHeight: popupDimensions.maxContentHeight)
                .onChange(of: selectedRow) { _, newFocus in
                    guard let newFocus else { return }
                    withAnimation(accessibilityReduceMotion ? nil : DesignTokens.Animation.hover) {
                        proxy.scrollTo(newFocus, anchor: .center)
                    }
                }
            }
        }
    }

    private var stateObservedPopup: some View {
        popupLayout
        .background(
            WindowAppearanceBridge(appearance: audioEngine.settingsManager.appSettings.appearance.nsAppearance)
                .frame(width: 0, height: 0)
        )
        .preferredColorScheme(audioEngine.settingsManager.appSettings.appearance.swiftUIColorScheme)
        .environment(\.appearancePreference, audioEngine.settingsManager.appSettings.appearance)
        .onAppear {
            updateSortedDevices()
            updateSortedInputDevices()
            pairedDevices = audioEngine.bluetoothDeviceMonitor.pairedDevices
            isBluetoothOn = audioEngine.bluetoothDeviceMonitor.isBluetoothOn
            // popupVisibility.isVisible is driven by the filtered NSWindow key
            // notifications below, not by .onAppear — SwiftUI mounts this view
            // before the popup is actually shown, and setting isVisible here
            // would suppress the HUD on the first media key at cold launch.
        }
        .onChange(of: audioEngine.outputDevices) { _, _ in
            if devicePriorityEditMode == .output {
                deviceReorderDragState.reset()
                mergeDeviceChanges(from: audioEngine.outputDevices)
            }
            updateSortedDevices()
            syncNavOrder()
        }
        .onChange(of: audioEngine.inputDevices) { _, _ in
            if devicePriorityEditMode == .input {
                deviceReorderDragState.reset()
                mergeDeviceChanges(from: audioEngine.inputDevices)
            }
            updateSortedInputDevices()
            syncNavOrder()
        }
        .onChange(of: popupPage.direction) { _, _ in
            syncNavOrder()
            if hasKeyboardEngaged {
                selectedRow = navModel.defaultFocus(defaultOutputUID: currentDefaultDeviceUID())
            }
        }
        .onChange(of: audioEngine.apps) { _, _ in
            cancelAppReorderIfNeeded()
            syncNavOrder()
        }
        .onChange(of: isEditingDevicePriority) { _, editing in
            if editing {
                selectedRow = nil
                hasKeyboardEngaged = false
            }
            syncNavOrder()
        }
        .onChange(of: audioEngine.bluetoothDeviceMonitor.pairedDevices) { _, newValue in
            pairedDevices = newValue
        }
        .onChange(of: audioEngine.bluetoothDeviceMonitor.isBluetoothOn) { _, newValue in
            isBluetoothOn = newValue
        }
        .onChange(of: deviceVolumeMonitor.defaultDeviceID) { _, _ in
            updateSortedDevices()
        }
    }

    var body: some View {
        stateObservedPopup
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            // Global notification — fires for every window in the process. Filter to
            // FineTune's own popup so unrelated windows (the HID-tap primer,
            // NSAlert panels, etc.) don't mark the popup as visible and suppress the HUD.
            guard let window = notification.object as? NSWindow,
                  String(describing: type(of: window)).contains("FluidMenuBarExtra")
            else { return }
            isPopupVisible = true
            popupVisibility.isVisible = true
            audioEngine.bluetoothDeviceMonitor.refresh()
            syncNavOrder()
            hasKeyboardEngaged = false
            selectedRow = nil
            anchorFocused = true
            textEntry.buffer = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notification in
            guard let window = notification.object as? NSWindow,
                  String(describing: type(of: window)).contains("FluidMenuBarExtra")
            else { return }
            hasKeyboardEngaged = false
            selectedRow = nil
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                if !window.isVisible {
                    isPopupVisible = false
                    popupVisibility.isVisible = false
                    resetToRootPage()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            // SwiftUI Menu tracking (e.g. sample-rate picker in the device
            // inspector) makes the popup window resign key without deactivating
            // the app. Only treat app-level deactivation as a real dismiss so
            // in-popup pickers don't collapse edit mode.
            exitEditModeSaving()
        }
        // Single focus anchor on the body root. `.onKeyPress` only fires when
        // the modifier-owning view (or a focused descendant) has focus, so the
        // anchor must claim it on popup open. `.focusEffectDisabled` suppresses
        // the OS-drawn focus ring around the entire popup.
        .focusable()
        .focusEffectDisabled()
        .focused($anchorFocused)
        // [.down, .repeat] is required so holding a key keeps moving the
        // selection or adjusting volume — `.down` alone fires once per press.
        .onKeyPress(phases: [.down, .repeat]) { keyPress in
            handleKeyPress(keyPress)
        }
        .environment(textEntry)
        .onChange(of: textEntry.navRestoreNonce) { _, _ in
            // A mouse-driven field edit ended; reclaim nav focus so arrows/Return work.
            anchorFocused = true
        }
        .background {
            Button("") { handleEscape() }
                .keyboardShortcut(.escape, modifiers: [])
                .hidden()
        }
    }

    /// Handles Escape key: collapses the current structural expansion before
    /// dismissing the popup. Device detail remains ahead of edit-mode teardown.
    private func handleEscape() {
        // The hidden Escape keyboardShortcut button can win over `.onKeyPress`, so an
        // in-progress keyboard entry is cancelled here too.
        if textEntry.buffer != nil {
            textEntry.buffer = nil
            return
        }
        if expansionState.deviceUID != nil {
            withAnimation(structuralExpansionAnimation) {
                expansionState.collapseDevice()
            }
        } else if isEditingDevicePriority {
            toggleDevicePriorityEdit()
        } else if expansionState.appID != nil {
            withAnimation(structuralExpansionAnimation) {
                expansionState.collapseApp()
            }
        } else {
            NSApp.keyWindow?.resignKey()
        }
    }

    private func openSettingsWindow() {
        exitEditModeSaving()
        NSApp.keyWindow?.resignKey()
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            devicesSection

            if let editMode = devicePriorityEditMode {
                if editMode == .output {
                    Divider()
                        .padding(.vertical, DesignTokens.Spacing.xs)

                    PopupAppVisibilityPane(audioEngine: audioEngine)
                }
            } else {
                Divider()
                    .padding(.vertical, DesignTokens.Spacing.xs)

                appsSection
            }
        }
    }

    // MARK: - Subviews

    private var devicesSection: some View {
        PopupDevicePane(
            audioEngine: audioEngine,
            deviceVolumeMonitor: deviceVolumeMonitor,
            direction: popupPage.direction,
            isManaging: isEditingDevicePriority,
            sortedOutputDevices: sortedDevices,
            sortedInputDevices: sortedInputDevices,
            editableDeviceOrder: editableDeviceOrder,
            pairedDevices: pairedDevices,
            isBluetoothOn: isBluetoothOn,
            expansionState: expansionState,
            reorderDragState: deviceReorderDragState,
            autoEQImportError: autoEQImportError,
            focusedRow: hasKeyboardEngaged ? selectedRow : nil,
            onImportAutoEQ: { deviceUID in
                importAutoEQFile(for: deviceUID)
            },
            onToggleDeviceExpansion: { deviceUID in
                withAnimation(structuralExpansionAnimation) {
                    _ = expansionState.toggleDevice(deviceUID)
                }
            },
            onReorderChanged: { deviceUID, rawTranslation in
                updateDeviceReorder(
                    deviceUID: deviceUID,
                    rawTranslation: rawTranslation
                )
            },
            onReorderEnded: { deviceUID in
                endDeviceReorder(deviceUID: deviceUID)
            },
            onReorder: { deviceUID, newIndex in
                reorderEditableDevice(deviceUID: deviceUID, to: newIndex)
            }
        )
    }

    private var appsSection: some View {
        PopupAppPane(
            audioEngine: audioEngine,
            deviceVolumeMonitor: deviceVolumeMonitor,
            permission: permission,
            apps: presentedDisplayableApps,
            pinnedIdentifiers: presentedPinnedAppIDs,
            outputDevices: sortedDevices,
            isPopupVisible: isPopupVisible,
            expandedAppID: expansionState.appID,
            sliderWidth: popupDimensions.appSliderWidth,
            draggedAppID: appReorderDragState.draggedID,
            draggedAppOffset: appReorderDragState.effectiveTranslation,
            focusedRow: hasKeyboardEngaged ? selectedRow : nil,
            contentGutter: Self.scrollbarContentGutter,
            appSelectionError: appSelectionError,
            onEQToggle: { appID in
                toggleEQ(for: appID)
            },
            onTogglePin: { appID in
                audioEngine.setPinned(
                    appID,
                    pinned: !audioEngine.isPinned(identifier: appID)
                )
                syncNavOrder()
            },
            onAddApplications: {
                selectApplications()
            },
            onReorderChanged: { appID, rawTranslation in
                updateAppReorder(
                    appID: appID,
                    rawTranslation: rawTranslation
                )
            },
            onReorderEnded: { appID in
                endAppReorder(appID: appID)
            },
            canReorder: { appID, direction in
                appReorderStep(for: appID, direction: direction) != nil
            },
            onAccessibleReorder: { appID, direction in
                reorderAppFromAccessibility(appID: appID, direction: direction)
            }
        )
    }

    /// Toggles App EQ through one structural action for pointer and keyboard.
    /// `PopupAppPane` owns semantic scroll anchoring after the expanded layout exists.
    private func toggleEQ(for appID: String) {
        withAnimation(structuralExpansionAnimation) {
            _ = expansionState.toggleApp(appID)
        }
    }

    private static let continuousReorderGlide =
        DesignTokens.Animation.reorder

    private static let reorderRowExtent = DesignTokens.Dimensions.rowContentHeight + 12

    private var presentedDisplayableApps: [DisplayableApp] {
        let liveApps = audioEngine.displayableApps
        guard let transientAppOrder else { return liveApps }

        let byIdentifier = Dictionary(
            uniqueKeysWithValues: liveApps.map { ($0.id, $0) }
        )
        let reordered = transientAppOrder.compactMap { byIdentifier[$0] }
        guard reordered.count == liveApps.count else { return liveApps }
        return reordered
    }

    private var presentedPinnedAppIDs: Set<String> {
        if let transientPinnedAppIDs {
            return transientPinnedAppIDs
        }
        return Set(
            audioEngine.displayableApps.lazy
                .filter { audioEngine.isPinned(identifier: $0.id) }
                .map(\.id)
        )
    }

    private func appReorderStep(for appID: String, direction: Int) -> AppListPresentationOrder.ReorderStep? {
        let apps = audioEngine.displayableApps
        return AppListPresentationOrder.reorderStep(
            for: appID,
            direction: direction,
            orderedIdentifiers: apps.map(\.id),
            pinnedIdentifiers: Set(
                apps.lazy
                    .filter { audioEngine.isPinned(identifier: $0.id) }
                    .map(\.id)
            )
        )
    }

    private func reorderAppFromAccessibility(appID: String, direction: Int) {
        guard let step = appReorderStep(for: appID, direction: direction) else { return }
        _ = audioEngine.placeApp(
            appID,
            visibleOrder: step.orderedIdentifiers,
            pinned: step.pinned
        )
        syncNavOrder()
    }

    private func updateDeviceReorder(deviceUID: String, rawTranslation: CGFloat) {
        if deviceReorderDragState.draggedID != deviceUID {
            expansionState.collapseDevice()
        }

        deviceReorderDragState.update(id: deviceUID, rawTranslation: rawTranslation)
        guard var index = editableDeviceOrder.firstIndex(where: { $0.uid == deviceUID }) else {
            deviceReorderDragState.reset()
            return
        }

        while let direction = deviceReorderDragState.consumeCrossingIfNeeded(
            rowExtent: Self.reorderRowExtent,
            index: index,
            count: editableDeviceOrder.count
        ) {
            let adjacentIndex = index + direction
            withAnimation(accessibilityReduceMotion ? nil : Self.continuousReorderGlide) {
                editableDeviceOrder.swapAt(index, adjacentIndex)
            }
            index = adjacentIndex
        }
    }

    private func endDeviceReorder(deviceUID: String) {
        guard deviceReorderDragState.draggedID == deviceUID else { return }
        withAnimation(accessibilityReduceMotion ? nil : Self.continuousReorderGlide) {
            deviceReorderDragState.reset()
        }
    }

    private func updateAppReorder(appID: String, rawTranslation: CGFloat) {
        if appReorderDragState.draggedID != appID {
            expansionState.collapseApp()
            let displayableApps = audioEngine.displayableApps
            let initialOrder = displayableApps.map(\.id)
            appReorderInitialOrder = initialOrder
            transientAppOrder = initialOrder
            transientPinnedAppIDs = Set(
                displayableApps.lazy
                    .filter { audioEngine.isPinned(identifier: $0.id) }
                    .map(\.id)
            )
        }

        appReorderDragState.update(id: appID, rawTranslation: rawTranslation)
        guard var order = transientAppOrder,
              var pinnedIDs = transientPinnedAppIDs,
              order.contains(appID) else {
            cancelAppReorderIfNeeded()
            return
        }

        while true {
            let direction: Int
            if appReorderDragState.effectiveTranslation > 0 {
                direction = 1
            } else if appReorderDragState.effectiveTranslation < 0 {
                direction = -1
            } else {
                break
            }

            guard let step = AppListPresentationOrder.reorderStep(
                for: appID,
                direction: direction,
                orderedIdentifiers: order,
                pinnedIdentifiers: pinnedIDs
            ) else { break }

            let extent = step.crossesSectionBoundary
                ? PopupAppPane.groupHeaderExtent
                : Self.reorderRowExtent
            guard appReorderDragState.consumeCrossingIfNeeded(
                extent: extent,
                direction: direction
            ) else { break }

            order = step.orderedIdentifiers
            if step.pinned {
                pinnedIDs.insert(appID)
            } else {
                pinnedIDs.remove(appID)
            }
            withAnimation(accessibilityReduceMotion ? nil : Self.continuousReorderGlide) {
                transientAppOrder = order
                transientPinnedAppIDs = pinnedIDs
            }
        }
    }

    private func endAppReorder(appID: String) {
        guard appReorderDragState.draggedID == appID else { return }

        if let initialOrder = appReorderInitialOrder,
           let finalOrder = transientAppOrder,
           let finalPinnedIDs = transientPinnedAppIDs,
           initialOrder.count == finalOrder.count,
           Set(initialOrder) == Set(finalOrder) {
            _ = audioEngine.placeApp(
                appID,
                visibleOrder: finalOrder,
                pinned: finalPinnedIDs.contains(appID)
            )
        }

        withAnimation(accessibilityReduceMotion ? nil : Self.continuousReorderGlide) {
            appReorderDragState.reset()
            transientAppOrder = nil
            transientPinnedAppIDs = nil
        }
        appReorderInitialOrder = nil
        syncNavOrder()
    }

    private func cancelAppReorderIfNeeded() {
        guard appReorderDragState.draggedID != nil
                || transientAppOrder != nil
                || appReorderInitialOrder != nil
                || transientPinnedAppIDs != nil else {
            return
        }
        appReorderDragState.reset()
        transientAppOrder = nil
        appReorderInitialOrder = nil
        transientPinnedAppIDs = nil
    }

    private func selectApplications() {
        appSelectionError = nil
        NSApp.keyWindow?.resignKey()

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        let localization = LocalizationContext(
            language: audioEngine.settingsManager.appSettings.language
        )
        panel.message = localization.localized("Choose one or more applications to add.")
        panel.prompt = localization.localized("Add")
        NSApp.activate()
        panel.begin { response in
            guard response == .OK else { return }

            let selected = panel.urls.compactMap { PinnedAppInfo(appURL: $0) }
            Task { @MainActor in
                for info in selected {
                    audioEngine.addSelectedApplication(info)
                }
                appSelectionError = selected.count == panel.urls.count
                    ? nil
                    : LocalizedStringResource(
                        "Some applications could not be added because they were invalid, missing a bundle identifier, or were FineTune."
                    )
                syncNavOrder()
            }
        }
    }

    private func reorderEditableDevice(deviceUID: String, to targetIndex: Int) {
        let currentIdentifiers = editableDeviceOrder.map(\.uid)
        guard let reorderedIdentifiers = DeviceReorderAccessibility.reorderedIdentifiers(
            currentIdentifiers,
            moving: deviceUID,
            to: targetIndex
        ) else {
            return
        }

        let devicesByUID = Dictionary(
            uniqueKeysWithValues: editableDeviceOrder.map { ($0.uid, $0) }
        )
        let reorderedDevices = reorderedIdentifiers.compactMap { devicesByUID[$0] }
        guard reorderedDevices.count == editableDeviceOrder.count else { return }

        withAnimation(accessibilityReduceMotion ? nil : Self.continuousReorderGlide) {
            editableDeviceOrder = reorderedDevices
        }
    }

    // MARK: - Device Priority Edit

    private func toggleDevicePriorityEdit() {
        if isEditingDevicePriority {
            // Exiting edit mode: persist to the correct priority list and
            // collapse any expanded device detail (the inline body only lives
            // inside edit mode, so it must collapse when the mode does).
            let direction = exitEditModeSaving()
            if direction == .input {
                updateSortedInputDevices()
            } else {
                updateSortedDevices()
            }
        } else {
            // Entering edit mode: use the full (unfiltered) device list so hidden devices are also shown.
            let direction = popupPage.direction
            editableDeviceOrder = direction.isInput
                ? audioEngine.prioritySortedInputDevices
                : audioEngine.prioritySortedOutputDevices
            popupPage = popupPage.enteringManagement()
        }
    }

    /// Persists the editable order to the correct priority list, preserving disconnected device positions.
    private func persistEditableOrder(for direction: PopupAudioDirection) {
        let connectedOrder = editableDeviceOrder.map(\.uid)
        if direction.isInput {
            audioEngine.settingsManager.mergeInputDevicePriorityOrder(
                oldPriority: audioEngine.settingsManager.inputDevicePriorityOrder,
                connectedOrder: connectedOrder
            )
        } else {
            audioEngine.settingsManager.mergeDevicePriorityOrder(
                oldPriority: audioEngine.settingsManager.devicePriorityOrder,
                connectedOrder: connectedOrder
            )
        }
    }

    /// Exits edit mode, saving the current order. Called on edge cases like device changes.
    @discardableResult
    private func exitEditModeSaving() -> PopupAudioDirection? {
        guard case .management(let direction) = popupPage else { return nil }
        deviceReorderDragState.reset()
        persistEditableOrder(for: direction)
        expansionState.collapseDevice()
        popupPage = .main(direction)
        return direction
    }

    private func resetToRootPage() {
        exitEditModeSaving()
        cancelAppReorderIfNeeded()
        expansionState.reset()
        popupPage = .main(.output)
    }

    /// Merges device list changes into `editableDeviceOrder` while preserving the user's reordering.
    /// Existing devices are refreshed (CoreAudio may reassign AudioDeviceIDs), removed devices are
    /// dropped, and reconnecting devices are inserted at their saved priority position.
    private func mergeDeviceChanges(from latest: [AudioDevice]) {
        let latestByUID = Dictionary(latest.map { ($0.uid, $0) }, uniquingKeysWith: { _, new in new })
        let priorityOrder = devicePriorityEditMode?.isInput == true
            ? audioEngine.settingsManager.inputDevicePriorityOrder
            : audioEngine.settingsManager.devicePriorityOrder

        withAnimation(accessibilityReduceMotion ? nil : DesignTokens.Animation.selection) {
            // Remove devices that disappeared
            editableDeviceOrder.removeAll { latestByUID[$0.uid] == nil }

            // Refresh existing devices in case AudioDeviceID changed
            for i in editableDeviceOrder.indices {
                if let updated = latestByUID[editableDeviceOrder[i].uid] {
                    editableDeviceOrder[i] = updated
                }
            }

            // Insert reconnecting devices at their saved priority position
            let existingUIDs = Set(editableDeviceOrder.map(\.uid))
            let newDevices = latest.filter { !existingUIDs.contains($0.uid) }
            for device in newDevices {
                let index = Self.priorityInsertionIndex(
                    for: device.uid,
                    in: editableDeviceOrder.map(\.uid),
                    priorityOrder: priorityOrder
                )
                editableDeviceOrder.insert(device, at: index)
            }
        }
    }

    /// Finds the best insertion index for a reconnecting device based on saved priority order.
    ///
    /// Walks `priorityOrder` to find the UIDs that come before and after `uid`, then
    /// places the device between them in `currentOrder`. Falls back to appending at the end
    /// if the device isn't in the priority list or no neighbors are present.
    ///
    /// - Parameters:
    ///   - uid: The device UID to insert.
    ///   - currentOrder: The current list of device UIDs.
    ///   - priorityOrder: The saved full priority list.
    /// - Returns: The index at which to insert the device.
    static func priorityInsertionIndex(for uid: String, in currentOrder: [String], priorityOrder: [String]) -> Int {
        guard let priorityIndex = priorityOrder.firstIndex(of: uid) else {
            // Brand new device not in priority list — append at end
            return currentOrder.count
        }

        // Find the closest priority neighbor that exists in currentOrder and comes AFTER uid in priority.
        // Insert before that neighbor so uid takes its correct position.
        for i in (priorityIndex + 1)..<priorityOrder.count {
            let successor = priorityOrder[i]
            if let currentIndex = currentOrder.firstIndex(of: successor) {
                return currentIndex
            }
        }

        // No successor found — insert at end
        return currentOrder.count
    }

    // MARK: - Helpers

    /// Recomputes sorted output devices, filtering hidden ones.
    /// The current default output device is always kept visible even if hidden.
    /// Falls back to the unfiltered list if the filter produces an empty
    /// result — `defaultDeviceUID` can be briefly nil during device switchover
    /// and we don't want the main view to show zero rows in that window.
    private func updateSortedDevices() {
        let all = audioEngine.prioritySortedOutputDevices
        let defaultUID = deviceVolumeMonitor.defaultDeviceUID
        let filtered = all.filter { device in
            device.uid == defaultUID || !audioEngine.settingsManager.isOutputDeviceHidden(device.uid)
        }
        sortedDevices = filtered.isEmpty ? all : filtered
    }

    /// Recomputes sorted input devices. Input management is priority-only, so
    /// every connected input remains reachable from the main view.
    private func updateSortedInputDevices() {
        sortedInputDevices = audioEngine.prioritySortedInputDevices
    }

    /// Opens a file panel to import a ParametricEQ.txt for a device
    private func importAutoEQFile(for deviceUID: String) {
        // Dismiss the main popup so the file picker isn't obscured
        NSApp.keyWindow?.resignKey()

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        let localization = LocalizationContext(
            language: audioEngine.settingsManager.appSettings.language
        )
        panel.message = localization.localized("Select an AutoEQ ParametricEQ.txt file")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let name = url.deletingPathExtension().lastPathComponent
            Task { @MainActor in
                if let profile = audioEngine.autoEQProfileManager.importProfile(from: url, name: name) {
                    audioEngine.setAutoEQProfile(for: deviceUID, profileID: profile.id)
                    autoEQImportError = nil
                } else {
                    autoEQImportError = LocalizedStringResource(
                        "Could not read profile. Check the file format."
                    )
                    importErrorClearTask?.cancel()
                    importErrorClearTask = Task {
                        try? await Task.sleep(for: .seconds(3))
                        guard !Task.isCancelled else { return }
                        withAnimation { autoEQImportError = nil }
                    }
                }
            }
        }
    }

    // MARK: - Keyboard Navigation

    private func syncNavOrder() {
        let activeDevices = showingInputDevices ? sortedInputDevices : sortedDevices
        navModel.syncOrder(
            activeDevices: activeDevices,
            appPersistenceIDs: presentedDisplayableApps.map(\.id),
            isEditingPriority: isEditingDevicePriority
        )
    }

    private func currentDefaultDeviceUID() -> String? {
        showingInputDevices
            ? deviceVolumeMonitor.defaultInputDeviceUID
            : deviceVolumeMonitor.defaultDeviceUID
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        // `.onKeyPress` also fires for focused descendants; yield while a TextField is editing so its Return commits via onSubmit instead of activating a row.
        if NSApp.keyWindow?.firstResponder is NSTextView { return .ignored }
        // Keyboard entry mode: the popup owns every key so the anchor keeps first responder.
        if textEntry.buffer != nil {
            return handleKeyboardEditKey(keyPress)
        }
        let mods = keyPress.modifiers
        let isM = keyPress.key == KeyEquivalent("m")
        let editSeed = digitSeed(for: keyPress)
        let isRecognized: Bool = {
            switch keyPress.key {
            case .upArrow, .downArrow, .leftArrow, .rightArrow, .return, .space, .tab:
                return true
            default:
                return isM || editSeed != nil
            }
        }()
        // Wake gate: compute target locally so first-press actions never read a
        // stale selection. ↑/↓ wake without moving; action keys wake and act on
        // the default in the same press.
        let target: PopupKeyboardNavModel.RowID?
        let wokeUp: Bool
        if !hasKeyboardEngaged && isRecognized {
            hasKeyboardEngaged = true
            target = navModel.defaultFocus(defaultOutputUID: currentDefaultDeviceUID())
            selectedRow = target
            wokeUp = true
        } else {
            target = selectedRow
            wokeUp = false
        }
        switch keyPress.key {
        case .upArrow:
            if wokeUp { return target == nil ? .ignored : .handled }
            if let next = navModel.previous(before: target) {
                selectedRow = next
                return .handled
            }
            return .ignored
        case .downArrow:
            if wokeUp { return target == nil ? .ignored : .handled }
            if let next = navModel.next(after: target) {
                selectedRow = next
                return .handled
            }
            return .ignored
        case .leftArrow:
            return adjustVolume(at: target, direction: -1, shift: mods.contains(.shift))
        case .rightArrow:
            return adjustVolume(at: target, direction: +1, shift: mods.contains(.shift))
        case .return, .space:
            return activate(target)
        case .tab:
            guard case .device = target else { return .ignored }
            toggleDeviceTab()
            return .handled
        default:
            if let editSeed, keyPress.phase == .down, target != nil {
                textEntry.buffer = editSeed
                return .handled
            }
            return isM ? toggleMute(for: target) : .ignored
        }
    }

    /// Consumes every key while entry is active so editing keystrokes never leak to navigation.
    private func handleKeyboardEditKey(_ keyPress: KeyPress) -> KeyPress.Result {
        // The Mac ⌫ key arrives as DEL (U+007F), which `KeyEquivalent.delete` doesn't match.
        if keyPress.characters == "\u{7f}" || keyPress.key == .delete {
            let next = String((textEntry.buffer ?? "").dropLast())
            textEntry.buffer = next.isEmpty ? nil : next
            return .handled
        }
        switch keyPress.key {
        case .return:
            textEntry.commitNonce += 1
            return .handled
        case .escape:
            textEntry.buffer = nil
            return .handled
        default:
            if let digit = digitSeed(for: keyPress), keyPress.phase == .down {
                let current = textEntry.buffer ?? ""
                if current.count < 4 {
                    textEntry.buffer = current + digit
                }
            }
            return .handled
        }
    }

    /// The bare digit `0`–`9` for this key press, or nil (modifier combos excluded).
    private func digitSeed(for keyPress: KeyPress) -> String? {
        guard keyPress.modifiers.intersection([.command, .control, .option]).isEmpty,
              keyPress.characters.count == 1,
              let ch = keyPress.characters.first,
              ("0"..."9").contains(ch)
        else { return nil }
        return String(ch)
    }

    private func adjustVolume(at target: PopupKeyboardNavModel.RowID?, direction: Int, shift: Bool) -> KeyPress.Result {
        guard let target else { return .ignored }
        let baseStep = audioEngine.settingsManager.appSettings.volumeHotkeyStep.sliderDelta
        let step = shift ? baseStep * 2.0 : baseStep
        let delta = step * Double(direction)
        switch target {
        case .app(let persistenceID):
            if let app = audioEngine.apps.first(where: { $0.persistenceIdentifier == persistenceID }) {
                applyAppVolumeStep(
                    currentGain: audioEngine.currentVolume(for: app),
                    currentMute: audioEngine.isMuted(for: app),
                    delta: delta,
                    setGain: { audioEngine.setVolume(for: app, to: $0) },
                    setMute: { audioEngine.setMute(for: app, to: $0) }
                )
                return .handled
            }
            return .ignored
        case .device(let uid):
            if showingInputDevices {
                guard let device = sortedInputDevices.first(where: { $0.uid == uid }) else {
                    return .ignored
                }
                let currentFraction = Double(deviceVolumeMonitor.inputVolumes[device.id] ?? 1.0)
                deviceVolumeMonitor.applyUserInputVolume(
                    for: device.id,
                    to: Float(currentFraction + delta)
                )
            } else {
                guard let device = sortedDevices.first(where: { $0.uid == uid }) else {
                    return .ignored
                }
                let backend = deviceVolumeMonitor.outputVolumeBackend(for: device.id)
                let currentMute = deviceVolumeMonitor.muteStates[device.id] ?? false
                let plan = OutputVolumeCommandPlan.step(
                    currentGain: deviceVolumeMonitor.storedOutputVolume(for: device.id),
                    isMuted: currentMute,
                    tier: backend,
                    delta: delta
                )
                deviceVolumeMonitor.applyOutputCommand(plan, for: device.id)
            }
            return .handled
        }
    }

    /// Mirrors `ShortcutsRegistry.adjustTargetVolume`'s mute-edge semantics for
    /// both active and pinned-inactive app rows.
    private func applyAppVolumeStep(
        currentGain: Float,
        currentMute: Bool,
        delta: Double,
        setGain: (Float) -> Void,
        setMute: (Bool) -> Void
    ) {
        AppVolumeCommandPlan.step(
            currentGain: currentGain,
            isMuted: currentMute,
            delta: delta
        ).apply(setVolume: setGain, setMute: setMute)
    }

    private func toggleMute(for target: PopupKeyboardNavModel.RowID?) -> KeyPress.Result {
        guard let target else { return .ignored }
        switch target {
        case .app(let persistenceID):
            if let app = audioEngine.apps.first(where: { $0.persistenceIdentifier == persistenceID }) {
                audioEngine.toggleMute(for: app)
                return .handled
            }
            return .ignored
        case .device(let uid):
            if showingInputDevices {
                guard let device = sortedInputDevices.first(where: { $0.uid == uid }) else {
                    return .ignored
                }
                deviceVolumeMonitor.toggleUserInputMute(for: device.id)
            } else {
                guard let device = sortedDevices.first(where: { $0.uid == uid }) else {
                    return .ignored
                }
                deviceVolumeMonitor.toggleUserOutputMute(for: device.id)
            }
            return .handled
        }
    }

    private func activate(_ target: PopupKeyboardNavModel.RowID?) -> KeyPress.Result {
        guard let target else { return .ignored }
        switch target {
        case .device(let uid):
            if showingInputDevices {
                guard let device = sortedInputDevices.first(where: { $0.uid == uid }) else {
                    return .ignored
                }
                audioEngine.setLockedInputDevice(device)
            } else {
                guard let device = sortedDevices.first(where: { $0.uid == uid }) else {
                    return .ignored
                }
                audioEngine.setDefaultOutputDevice(device.id)
            }
            return .handled
        case .app(let persistenceID):
            toggleEQ(for: persistenceID)
            return .handled
        }
    }

    private func selectDeviceTab(showInput: Bool) {
        let requestedDirection = PopupAudioDirection(showInput: showInput)
        guard let transition = popupPage.selecting(requestedDirection) else { return }

        if let directionToPersist = transition.managementDirectionToPersist {
            persistEditableOrder(for: directionToPersist)
            expansionState.collapseDevice()
            deviceReorderDragState.reset()
            editableDeviceOrder = requestedDirection.isInput
                ? audioEngine.prioritySortedInputDevices
                : audioEngine.prioritySortedOutputDevices
        }

        withAnimation(structuralExpansionAnimation) {
            popupPage = transition.page
        }
    }

    private func toggleDeviceTab() {
        selectDeviceTab(showInput: !showingInputDevices)
    }

    /// Activates an app, bringing it to foreground and restoring minimized windows

}

// MARK: - Previews

#Preview("Menu Bar Popup") {
    // Note: This preview requires mock AudioEngine and DeviceVolumeMonitor
    // For now, just show the structure
    PreviewContainer {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            SectionHeader(title: "Output Devices")
                .padding(.bottom, DesignTokens.Spacing.xs)

            ForEach(MockData.sampleDevices.prefix(2)) { device in
                DeviceRow(
                    device: device,
                    isDefault: device == MockData.sampleDevices[0],
                    volume: 0.75,
                    isMuted: false,
                    onSetDefault: {},
                    onVolumeCommand: { _ in }
                )
            }

            Divider()
                .padding(.vertical, DesignTokens.Spacing.xs)

            SectionHeader(title: "Apps")
                .padding(.bottom, DesignTokens.Spacing.xs)

            ForEach(MockData.sampleApps.prefix(3)) { app in
                AppRow(
                    app: app,
                    volume: Float.random(in: 0.5...1.5),
                    audioLevel: Float.random(in: 0...0.7),
                    devices: MockData.sampleDevices,
                    selectedDeviceUID: MockData.sampleDevices[0].uid,
                    isMuted: false,
                    onVolumeChange: { _ in },
                    onMuteChange: { _ in },
                    onDeviceSelected: { _ in },
                    isReordering: false,
                    reorderOffset: 0,
                    onReorderChanged: { _ in },
                    onReorderEnded: {}
                )
            }

            Divider()
                .padding(.vertical, DesignTokens.Spacing.xs)

            Button {} label: {
                HStack(spacing: 6) {
                    Text("Quit")
                    Text("⌘Q")
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(DesignTokens.Colors.textTertiary)
            .font(DesignTokens.Typography.caption)
        }
    }
}
