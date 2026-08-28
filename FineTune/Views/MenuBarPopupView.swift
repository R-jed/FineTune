// FineTune/Views/MenuBarPopupView.swift
import AudioToolbox
import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum PopupDevicePriorityEditMode: Equatable {
    case output
    case input

    init(showingInputDevices: Bool) {
        self = showingInputDevices ? .input : .output
    }

    var includesAppManagement: Bool { self == .output }
    var isInput: Bool { self == .input }
}

struct PopupDeviceTabSelectionTransition: Equatable {
    let showInput: Bool
    let editModeToExit: PopupDevicePriorityEditMode?
}

struct PopupDevicePriorityEditSession: Equatable {
    private(set) var mode: PopupDevicePriorityEditMode?

    init(mode: PopupDevicePriorityEditMode? = nil) {
        self.mode = mode
    }

    mutating func begin(showingInputDevices: Bool) {
        mode = PopupDevicePriorityEditMode(showingInputDevices: showingInputDevices)
    }

    mutating func exit() -> PopupDevicePriorityEditMode? {
        defer { mode = nil }
        return mode
    }

    mutating func selectTab(
        currentlyShowingInput: Bool,
        requestedShowInput: Bool
    ) -> PopupDeviceTabSelectionTransition? {
        guard currentlyShowingInput != requestedShowInput else { return nil }
        return PopupDeviceTabSelectionTransition(
            showInput: requestedShowInput,
            editModeToExit: exit()
        )
    }
}

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

    /// Which device tab is selected (false = output, true = input)
    @State private var showingInputDevices = false

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

    /// Captures which pane owns the active priority edit session. Keeping the pane
    /// in the edit state avoids invalid combinations of separate editing/tab flags.
    @State private var devicePriorityEditSession = PopupDevicePriorityEditSession()

    /// Editable copy of device order for drag-and-drop reordering
    @State private var editableDeviceOrder: [AudioDevice] = []

    /// Hover state for support link heart animation
    @State private var isSupportHovered = false

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

    private var appSliderWidth: CGFloat {
        switch audioEngine.settingsManager.appSettings.popupSize {
        case .compact: 100
        case .comfortable: 120
        case .spacious: DesignTokens.Dimensions.sliderWidth
        }
    }

    private var structuralExpansionAnimation: Animation? {
        accessibilityReduceMotion ? nil : .easeOut(duration: 0.18)
    }

    private var isEditingDevicePriority: Bool {
        devicePriorityEditSession.mode != nil
    }

    private var devicePriorityEditMode: PopupDevicePriorityEditMode? {
        devicePriorityEditSession.mode
    }

    private var popupLayout: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                deviceTabsHeader
                Spacer()
                editPriorityButton
                settingsButton
            }
            .padding(.bottom, DesignTokens.Spacing.xs)

            ScrollViewReader { proxy in
                mainContent(scrollProxy: proxy)
                .onChange(of: selectedRow) { _, newFocus in
                    guard let newFocus else { return }
                    withAnimation(accessibilityReduceMotion ? nil : DesignTokens.Animation.hover) {
                        proxy.scrollTo(newFocus)
                    }
                }
            }

            Divider()
                .padding(.top, DesignTokens.Spacing.xs)

            footer
        }
        .padding(popupDimensions.contentPadding)
        .frame(width: popupDimensions.width)
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
                mergeDeviceChanges(from: audioEngine.outputDevices)
            }
            updateSortedDevices()
            syncNavOrder()
        }
        .onChange(of: audioEngine.inputDevices) { _, _ in
            if devicePriorityEditMode == .input {
                mergeDeviceChanges(from: audioEngine.inputDevices)
            }
            updateSortedInputDevices()
            syncNavOrder()
        }
        .onChange(of: showingInputDevices) { _, _ in
            syncNavOrder()
            if hasKeyboardEngaged {
                selectedRow = navModel.defaultFocus(defaultOutputUID: currentDefaultDeviceUID())
            }
        }
        .onChange(of: audioEngine.apps) { _, _ in syncNavOrder() }
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
            guard notification.object is FineTuneMenuBarPopupPanel else { return }
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
            guard let window = notification.object as? FineTuneMenuBarPopupPanel else { return }
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

    // MARK: - Edit Priority Button

    private var editPriorityTitle: LocalizedStringResource {
        if isEditingDevicePriority { return "Done managing" }
        return showingInputDevices ? "Manage Input" : "Manage Output"
    }

    /// Edit priority button — pencil ↔ checkmark, styled to match settingsButton
    private var editPriorityButton: some View {
        Button {
            toggleDevicePriorityEdit()
        } label: {
            Label(
                editPriorityTitle,
                systemImage: isEditingDevicePriority ? "checkmark" : "pencil"
            )
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: isEditingDevicePriority ? .bold : .regular))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(DesignTokens.Colors.interactiveDefault)
        .frame(
            minWidth: DesignTokens.Dimensions.minTouchTarget,
            minHeight: DesignTokens.Dimensions.minTouchTarget
        )
        .contentShape(Rectangle())
        .animation(
            accessibilityReduceMotion ? nil : .easeOut(duration: 0.12),
            value: isEditingDevicePriority
        )
        .help(editPriorityTitle)
    }

    // MARK: - Settings Button

    private var settingsButton: some View {
        Button(action: openSettingsWindow) {
            Image(systemName: "gearshape.fill")
        }
        .buttonStyle(.plain)
        .font(.system(size: 12))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(DesignTokens.Colors.interactiveDefault)
        .frame(
            minWidth: DesignTokens.Dimensions.minTouchTarget,
            minHeight: DesignTokens.Dimensions.minTouchTarget
        )
        .contentShape(Rectangle())
        .accessibilityLabel("Settings")
        .help("Settings")
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
    private func mainContent(scrollProxy: ScrollViewProxy) -> some View {
        if let editMode = devicePriorityEditMode {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    devicesSection

                    if editMode.includesAppManagement {
                        Divider()
                            .padding(.vertical, DesignTokens.Spacing.xs)

                        appVisibilitySection
                    }
                }
            }
            .scrollIndicators(.automatic)
            .contentMargins(.trailing, DesignTokens.Spacing.sm, for: .scrollContent)
            .frame(maxHeight: popupDimensions.maxContentHeight)
        } else {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                devicesSection

                Divider()
                    .padding(.vertical, DesignTokens.Spacing.xs)

                appsSection(scrollProxy: scrollProxy)
            }
        }
    }

    private var footer: some View {
        HStack {
                Button {
                    NSWorkspace.shared.open(DesignTokens.Links.support)
                } label: {
                    Label("Donate", systemImage: isSupportHovered ? "heart.fill" : "heart")
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSupportHovered ? Color(nsColor: .systemPink) : DesignTokens.Colors.textTertiary)
                .frame(minHeight: DesignTokens.Dimensions.minTouchTarget)
                .contentShape(Rectangle())
                .onHover { hovering in
                    isSupportHovered = hovering
                }
                .accessibilityLabel("Donate to FineTune")
                .help("Donate to FineTune")

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack(spacing: 6) {
                        Text("Quit")
                        Text("⌘Q")
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .accessibilityLabel("Quit FineTune")
                .help("Quit FineTune (⌘Q)")
        }
    }

    // MARK: - Device Toggle

    /// Native segmented control keeps switching behavior, focus, and pressed
    /// treatment aligned with the surrounding macOS controls.
    private var deviceTabsHeader: some View {
        Picker(
            "Audio direction",
            selection: Binding(
                get: { showingInputDevices },
                set: { selectDeviceTab(showInput: $0) }
            )
        ) {
            Label("Output", systemImage: "speaker.wave.2.fill")
                .tag(false)
            Label("Input", systemImage: "mic.fill")
                .tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
        .frame(width: 142)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var devicesSection: some View {
        devicesContent
    }

    private var devicesContent: some View {
        VStack(spacing: 0) {
            if isEditingDevicePriority {
                // Edit mode: drag-and-drop reordering (works for both output and input)
                let defaultDeviceID = showingInputDevices
                    ? deviceVolumeMonitor.defaultInputDeviceID
                    : deviceVolumeMonitor.defaultDeviceID
                ForEach(Array(editableDeviceOrder.enumerated()), id: \.element.uid) { index, device in
                    editableDeviceRow(device: device, index: index, defaultDeviceID: defaultDeviceID)
                }

                // Paired Bluetooth devices (output tab only)
                if !showingInputDevices {
                    if !isBluetoothOn {
                        Text("Turn on Bluetooth to connect devices")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, DesignTokens.Spacing.xs)
                    } else {
                        // Filter out any device already in the output list (handles
                        // IOBluetooth/CoreAudio timing desync where both report the device).
                        let connectedNames = Set(editableDeviceOrder.map(\.name))
                        let filteredPaired = pairedDevices.filter { !connectedNames.contains($0.name) }
                        if !filteredPaired.isEmpty {
                            SectionHeader(title: "Paired")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, DesignTokens.Spacing.xs)

                            ForEach(filteredPaired) { device in
                                PairedDeviceRow(
                                    device: device,
                                    isConnecting: audioEngine.bluetoothDeviceMonitor.connectingIDs.contains(device.id),
                                    errorMessage: audioEngine.bluetoothDeviceMonitor.connectionErrors[device.id],
                                    onConnect: {
                                        audioEngine.bluetoothDeviceMonitor.connect(device: device)
                                    }
                                )
                            }
                        }
                    }
                }
            } else if showingInputDevices {
                ForEach(sortedInputDevices) { device in
                    standardInputDeviceRow(device)
                }
            } else {
                ForEach(sortedDevices) { device in
                    standardOutputDeviceRow(device)
                }

            }
        }
    }

    @ViewBuilder
    private func standardInputDeviceRow(_ device: AudioDevice) -> some View {
        InputDeviceRow(
            device: device,
            isDefault: device.id == deviceVolumeMonitor.defaultInputDeviceID,
            volume: deviceVolumeMonitor.inputVolumes[device.id] ?? 1.0,
            isMuted: deviceVolumeMonitor.inputMuteStates[device.id] ?? false,
            onSetDefault: { audioEngine.setLockedInputDevice(device) },
            onUserVolumeChange: { volume in
                deviceVolumeMonitor.applyUserInputVolume(for: device.id, to: volume)
            },
            onUserMuteToggle: { deviceVolumeMonitor.toggleUserInputMute(for: device.id) },
            isFocused: hasKeyboardEngaged && selectedRow == .device(uid: device.uid),
            iconOverrideSymbol: audioEngine.settingsManager.getDeviceIconOverride(for: device.uid)
        )
        .id(PopupKeyboardNavModel.RowID.device(uid: device.uid))
    }

    @ViewBuilder
    private func standardOutputDeviceRow(_ device: AudioDevice) -> some View {
        let selection = audioEngine.getAutoEQSelection(for: device.uid)
        let profileName = selection.flatMap { selection in
            audioEngine.autoEQProfileManager.profile(for: selection.profileID)?.name
                ?? audioEngine.autoEQProfileManager.catalogEntry(for: selection.profileID)?.name
        }

        DeviceRow(
            device: device,
            isDefault: device.id == deviceVolumeMonitor.defaultDeviceID,
            volume: deviceVolumeMonitor.storedOutputVolume(for: device.id),
            isMuted: deviceVolumeMonitor.muteStates[device.id] ?? false,
            volumeBackend: audioEngine.outputVolumeBackend(for: device.id),
            onSetDefault: { audioEngine.setDefaultOutputDevice(device.id) },
            onVolumeCommand: { command in
                deviceVolumeMonitor.applyOutputCommand(command, for: device.id)
            },
            autoEQProfileName: profileName,
            autoEQEnabled: selection?.isEnabled ?? false,
            onAutoEQToggle: { enabled in
                audioEngine.setAutoEQEnabled(for: device.uid, enabled: enabled)
            },
            autoEQProfileManager: audioEngine.autoEQProfileManager,
            autoEQSelection: selection,
            autoEQFavoriteIDs: audioEngine.settingsManager.favoriteAutoEQProfileIDs,
            onAutoEQSelect: { profile in
                audioEngine.setAutoEQProfile(for: device.uid, profileID: profile?.id)
            },
            onAutoEQImport: { importAutoEQFile(for: device.uid) },
            onAutoEQToggleFavorite: { id in
                if audioEngine.settingsManager.isAutoEQFavorite(id: id) {
                    audioEngine.settingsManager.unfavoriteAutoEQProfile(id: id)
                } else {
                    audioEngine.settingsManager.favoriteAutoEQProfile(id: id)
                }
            },
            autoEQImportError: autoEQImportError,
            autoEQPreampEnabled: audioEngine.autoEQPreampEnabled,
            onAutoEQPreampToggle: {
                audioEngine.setAutoEQPreampEnabled(!audioEngine.autoEQPreampEnabled)
            },
            isFocused: hasKeyboardEngaged && selectedRow == .device(uid: device.uid),
            iconOverrideSymbol: audioEngine.settingsManager.getDeviceIconOverride(for: device.uid)
        )
        .id(PopupKeyboardNavModel.RowID.device(uid: device.uid))
    }

    /// Builds a single row for the priority-edit list. Extracted from
    /// `devicesContent` because the inline expression exceeded Swift's
    /// type-check budget once hide + expand + drop-destination were combined.
    @ViewBuilder
    private func editableDeviceRow(
        device: AudioDevice,
        index: Int,
        defaultDeviceID: AudioDeviceID
    ) -> some View {
        let isDeviceHidden = !showingInputDevices
            && audioEngine.settingsManager.isOutputDeviceHidden(device.uid)

        DeviceEditRow(
            device: device,
            iconOverrideSymbol: audioEngine.settingsManager.getDeviceIconOverride(for: device.uid),
            priorityIndex: index,
            isDefault: device.id == defaultDeviceID,
            isInputDevice: showingInputDevices,
            deviceCount: editableDeviceOrder.count,
            isExpanded: expansionState.deviceUID == device.uid,
            isHidden: isDeviceHidden,
            reorderDragPayload: Self.deviceReorderPayload(device.uid),
            onReorderDrop: { items in
                guard let sourceUID = Self.reorderIdentifier(
                    from: items,
                    prefix: Self.deviceReorderDragPrefix
                ), sourceUID != device.uid,
                      let targetIndex = editableDeviceOrder.firstIndex(where: { $0.uid == device.uid }) else {
                    return false
                }
                return reorderEditableDevice(deviceUID: sourceUID, to: targetIndex)
            },
            onReorder: { newIndex in
                _ = reorderEditableDevice(deviceUID: device.uid, to: newIndex)
            },
            onToggleExpand: showingInputDevices ? nil : {
                withAnimation(structuralExpansionAnimation) {
                    _ = expansionState.toggleDevice(device.uid)
                }
            },
            onToggleHidden: showingInputDevices ? nil : {
                audioEngine.settingsManager.toggleOutputDeviceHidden(uid: device.uid)
            },
            onIconSelect: showingInputDevices ? nil : { symbol in
                audioEngine.settingsManager.setDeviceIconOverride(for: device.uid, to: symbol)
            },
            expandedContent: {
                // Only render when actually expanded. Input devices skip
                // the expand, so this is never hit for them.
                if !showingInputDevices && expansionState.deviceUID == device.uid {
                    DeviceDetailSheet(
                        device: device,
                        transportType: device.id.readTransportType(),
                        autoDetectedTier: deviceVolumeMonitor.autoDetectedOutputVolumeBackend(for: device.id),
                        currentOverride: audioEngine.settingsManager.getDeviceVolumeTierOverride(for: device.uid),
                        onOverrideChange: { newTier in
                            audioEngine.settingsManager.setDeviceVolumeTierOverride(for: device.uid, to: newTier)
                            deviceVolumeMonitor.applyTierOverrideChange(for: device.id)
                        },
                        onDismiss: {}
                    )
                }
            }
        )
    }

    @ViewBuilder
    private var emptyStateView: some View {
        HStack {
            Spacer()
            VStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "speaker.slash")
                    .font(.title)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                Text("No audio apps running")
                    .font(.callout)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

                let ignoredCount = audioEngine.settingsManager.getIgnoredAppInfo().count
                if ignoredCount > 0 {
                    (Text(verbatim: "\(ignoredCount) ") + Text("hidden"))
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.xl)
    }

    @ViewBuilder
    private func appsSection(scrollProxy: ScrollViewProxy) -> some View {
        HStack {
    SectionHeader(title: "Apps")
    Spacer()
    AddApplicationsButton(action: selectApplications)
}
        .padding(.bottom, DesignTokens.Spacing.xs)

        if let appSelectionError {
            Label {
                Text(appSelectionError)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(DesignTokens.Typography.caption)
            .foregroundStyle(.orange)
            .padding(.bottom, DesignTokens.Spacing.xs)
        }

        if permission.status != .authorized {
            PermissionBannerView(permission: permission)
        } else if audioEngine.displayableApps.isEmpty {
            emptyStateView
        } else {
            ScrollView {
                appsContent(scrollProxy: scrollProxy)
            }
            .scrollIndicators(.visible)
            .contentMargins(.trailing, DesignTokens.Spacing.sm, for: .scrollContent)
            .frame(height: appViewportHeight)
        }
    }

    private let appVisibilityColumns = [
        GridItem(.flexible(), spacing: DesignTokens.Spacing.xs),
        GridItem(.flexible(), spacing: DesignTokens.Spacing.xs)
    ]

    private var appVisibilitySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            SectionHeader(title: "Apps")

            let visibleApps = audioEngine.displayableApps
            if !visibleApps.isEmpty {
                let orderedIdentifiers = visibleApps.map(\.id)
                let pinnedIdentifiers = Set(
                    orderedIdentifiers.filter { audioEngine.isPinned(identifier: $0) }
                )
                LazyVStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(visibleApps) { displayableApp in
                        appManagementRow(
                            displayableApp,
                            orderedIdentifiers: orderedIdentifiers,
                            pinnedIdentifiers: pinnedIdentifiers
                        )
                    }
                }
            }

            let ignoredApps = audioEngine.settingsManager.getIgnoredAppInfo()
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            if !ignoredApps.isEmpty {
                Divider()
                    .padding(.vertical, DesignTokens.Spacing.xs)

                Text("Hidden apps")
                    .sectionHeaderStyle()
                    .padding(.bottom, DesignTokens.Spacing.xs)

                LazyVGrid(columns: appVisibilityColumns, spacing: DesignTokens.Spacing.xs) {
                    ForEach(ignoredApps, id: \.persistenceIdentifier) { info in
                        AppManagementRow(
                            icon: DisplayableApp.loadIcon(bundleID: info.bundleID),
                            name: info.displayName,
                            isIgnored: true,
                            onToggleVisibility: { audioEngine.unignoreApp(info.persistenceIdentifier) }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func appManagementRow(
        _ displayableApp: DisplayableApp,
        orderedIdentifiers: [String],
        pinnedIdentifiers: Set<String>
    ) -> some View {
        let identifier = displayableApp.id
        let isPinned = pinnedIdentifiers.contains(identifier)
        let moveUpTarget = AppListPresentationOrder.reorderTarget(
            for: identifier,
            direction: -1,
            orderedIdentifiers: orderedIdentifiers,
            pinnedIdentifiers: pinnedIdentifiers
        )
        let moveDownTarget = AppListPresentationOrder.reorderTarget(
            for: identifier,
            direction: 1,
            orderedIdentifiers: orderedIdentifiers,
            pinnedIdentifiers: pinnedIdentifiers
        )

        AppManagementRow(
            icon: displayableApp.icon,
            name: displayableApp.displayName,
            isIgnored: false,
            isPinned: isPinned,
            reorderDragPayload: Self.appReorderPayload(identifier),
            onToggleVisibility: {
                switch displayableApp {
                case .active(let app): audioEngine.ignoreApp(app)
                case .pinnedInactive(let info): audioEngine.ignoreApp(info)
                }
            },
            onTogglePin: {
                switch displayableApp {
                case .active(let app):
                    if isPinned {
                        audioEngine.unpinApp(identifier)
                    } else {
                        audioEngine.pinApp(app)
                    }
                case .pinnedInactive(let info):
                    if isPinned {
                        audioEngine.unpinApp(identifier)
                    } else {
                        audioEngine.pinApp(info)
                    }
                }
            },
            onMoveUp: moveUpTarget.map { target in
                { audioEngine.moveApp(identifier, to: target) }
            },
            onMoveDown: moveDownTarget.map { target in
                { audioEngine.moveApp(identifier, to: target) }
            }
        )
        .dropDestination(for: String.self) { items, _ in
            guard let sourceIdentifier = Self.reorderIdentifier(
                from: items,
                prefix: Self.appReorderDragPrefix
            ), let targetIdentifier = AppListPresentationOrder.dropTarget(
                for: sourceIdentifier,
                onto: identifier,
                orderedIdentifiers: orderedIdentifiers,
                pinnedIdentifiers: pinnedIdentifiers
            ) else {
                return false
            }

            audioEngine.moveApp(sourceIdentifier, to: targetIdentifier)
            syncNavOrder()
            return true
        }
    }

    private var appViewportHeight: CGFloat {
        let collapsedRowHeight = DesignTokens.Dimensions.rowContentHeight + 12
        if expansionState.appID != nil {
            return collapsedRowHeight * 6
        }
        return collapsedRowHeight * CGFloat(min(audioEngine.displayableApps.count, 6))
    }

    private func selectApplications() {
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
                    audioEngine.pinApp(info)
                }
                appSelectionError = selected.count == panel.urls.count
                    ? nil
                    : LocalizedStringResource(
                        "Some applications could not be added because they were invalid, missing a bundle identifier, or were FineTune."
                    )
            }
        }
    }

    private func appsContent(scrollProxy: ScrollViewProxy) -> some View {
        let presets = audioEngine.settingsManager.getUserPresets()
        let displayableApps = audioEngine.displayableApps
        let pinnedApps = displayableApps.filter { audioEngine.isPinned(identifier: $0.id) }
        let runningApps = displayableApps.filter { !audioEngine.isPinned(identifier: $0.id) }

        return LazyVStack(alignment: .leading, spacing: 0) {
            if !pinnedApps.isEmpty {
                appGroupLabel("Pinned")
                ForEach(pinnedApps) { displayableApp in
                    appRow(
                        displayableApp,
                        userPresets: presets,
                        scrollProxy: scrollProxy
                    )
                }
            }

            if !runningApps.isEmpty {
                if !pinnedApps.isEmpty {
                    appGroupLabel("Running")
                        .padding(.top, DesignTokens.Spacing.xs)
                }
                ForEach(runningApps) { displayableApp in
                    appRow(
                        displayableApp,
                        userPresets: presets,
                        scrollProxy: scrollProxy
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func appGroupLabel(_ title: LocalizedStringResource) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .padding(.leading, DesignTokens.Spacing.sm)
            .padding(.bottom, DesignTokens.Spacing.xxs)
    }

    @ViewBuilder
    private func appRow(
        _ displayableApp: DisplayableApp,
        userPresets: [UserEQPreset],
        scrollProxy: ScrollViewProxy
    ) -> some View {
        switch displayableApp {
        case .active(let app):
            activeAppRow(
                app: app,
                displayableApp: displayableApp,
                userPresets: userPresets,
                scrollProxy: scrollProxy
            )
        case .pinnedInactive(let info):
            inactiveAppRow(
                info: info,
                displayableApp: displayableApp,
                userPresets: userPresets,
                scrollProxy: scrollProxy
            )
        }
    }

    /// Row for an active app (currently producing audio)
    @ViewBuilder
    private func activeAppRow(app: AudioApp, displayableApp: DisplayableApp, userPresets: [UserEQPreset], scrollProxy: ScrollViewProxy) -> some View {
        if let deviceUID = audioEngine.getDeviceUID(for: app) {
            let isPinned = audioEngine.isPinned(identifier: app.persistenceIdentifier)
            AppRowWithLevelPolling(
                app: app,
                volume: audioEngine.getVolume(for: app),
                isMuted: audioEngine.getMute(for: app),
                devices: sortedDevices,
                deviceIconOverrides: audioEngine.settingsManager.deviceIconOverrides,
                selectedDeviceUID: deviceUID,
                selectedDeviceUIDs: audioEngine.getSelectedDeviceUIDs(for: app),
                isFollowingDefault: audioEngine.isFollowingDefault(for: app),
                defaultDeviceUID: deviceVolumeMonitor.defaultDeviceUID,
                deviceSelectionMode: audioEngine.getDeviceSelectionMode(for: app),
                boost: audioEngine.getBoost(for: app),
                onBoostChange: { boost in
                    audioEngine.setBoost(for: app, to: boost)
                },
                getAudioLevel: { audioEngine.getAudioLevel(for: app) },
                isPopupVisible: isPopupVisible,
                onVolumeChange: { volume in
                    audioEngine.setVolume(for: app, to: volume)
                },
                onMuteChange: { muted in
                    audioEngine.setMute(for: app, to: muted)
                },
                onDeviceSelected: { newDeviceUID in
                    audioEngine.setDevice(for: app, deviceUID: newDeviceUID)
                },
                onDevicesSelected: { uids in
                    audioEngine.setSelectedDeviceUIDs(for: app, to: uids)
                },
                onDeviceModeChange: { mode in
                    audioEngine.setDeviceSelectionMode(for: app, to: mode)
                },
                onSelectFollowDefault: {
                    audioEngine.setDevice(for: app, deviceUID: nil)
                },
                onAppActivate: {
                    activateApp(pid: app.id, bundleID: app.bundleID)
                },
                eqSettings: audioEngine.getEQSettings(for: app),
                userPresets: userPresets,
                onEQChange: { settings in
                    audioEngine.setEQSettings(settings, for: app)
                },
                onUserPresetSelected: { userPreset in
                    // Apply only bandGains — preserve app's current isEnabled state
                    var current = audioEngine.getEQSettings(for: app)
                    current.bandGains = userPreset.settings.bandGains
                    audioEngine.setEQSettings(current, for: app)
                },
                onSavePreset: { name, settings in
                    audioEngine.settingsManager.createUserPreset(name: name, settings: settings)
                },
                onDeleteUserPreset: { id in
                    audioEngine.settingsManager.deleteUserPreset(id: id)
                },
                onRenameUserPreset: { id, newName in
                    audioEngine.settingsManager.updateUserPreset(id: id, name: newName)
                },
                isEQExpanded: expansionState.appID == displayableApp.id,
                onEQToggle: {
                    toggleEQ(for: displayableApp.id, scrollProxy: scrollProxy)
                },
                sliderWidth: appSliderWidth,
                isPinned: isPinned,
                onTogglePin: {
                    if isPinned {
                        audioEngine.unpinApp(app.persistenceIdentifier)
                    } else {
                        audioEngine.pinApp(app)
                    }
                },
                isFocused: hasKeyboardEngaged && selectedRow == .app(persistenceID: displayableApp.id)
            )
            .id(PopupKeyboardNavModel.RowID.app(persistenceID: displayableApp.id))
        }
    }

    /// Row for a pinned inactive app (not currently producing audio)
    @ViewBuilder
    private func inactiveAppRow(info: PinnedAppInfo, displayableApp: DisplayableApp, userPresets: [UserEQPreset], scrollProxy: ScrollViewProxy) -> some View {
        let identifier = info.persistenceIdentifier
        InactiveAppRow(
            appInfo: info,
            icon: displayableApp.icon,
            volume: audioEngine.getVolumeForInactive(identifier: identifier),
            devices: sortedDevices,
            deviceIconOverrides: audioEngine.settingsManager.deviceIconOverrides,
            selectedDeviceUID: audioEngine.getDeviceRoutingForInactive(identifier: identifier),
            selectedDeviceUIDs: audioEngine.getSelectedDeviceUIDsForInactive(identifier: identifier),
            isFollowingDefault: audioEngine.isFollowingDefaultForInactive(identifier: identifier),
            defaultDeviceUID: deviceVolumeMonitor.defaultDeviceUID,
            deviceSelectionMode: audioEngine.getDeviceSelectionModeForInactive(identifier: identifier),
            isMuted: audioEngine.getMuteForInactive(identifier: identifier),
            boost: audioEngine.getBoostForInactive(identifier: identifier),
            onBoostChange: { boost in
                audioEngine.setBoostForInactive(identifier: identifier, to: boost)
            },
            onVolumeChange: { volume in
                audioEngine.setVolumeForInactive(identifier: identifier, to: volume)
            },
            onMuteChange: { muted in
                audioEngine.setMuteForInactive(identifier: identifier, to: muted)
            },
            onDeviceSelected: { newDeviceUID in
                audioEngine.setDeviceRoutingForInactive(identifier: identifier, deviceUID: newDeviceUID)
            },
            onDevicesSelected: { uids in
                audioEngine.setSelectedDeviceUIDsForInactive(identifier: identifier, to: uids)
            },
            onDeviceModeChange: { mode in
                audioEngine.setDeviceSelectionModeForInactive(identifier: identifier, to: mode)
            },
            onSelectFollowDefault: {
                audioEngine.setDeviceRoutingForInactive(identifier: identifier, deviceUID: nil)
            },
            eqSettings: audioEngine.getEQSettingsForInactive(identifier: identifier),
            userPresets: userPresets,
            onEQChange: { settings in
                audioEngine.setEQSettingsForInactive(settings, identifier: identifier)
            },
            onUserPresetSelected: { userPreset in
                // Apply only bandGains — preserve app's current isEnabled state
                var current = audioEngine.getEQSettingsForInactive(identifier: identifier)
                current.bandGains = userPreset.settings.bandGains
                audioEngine.setEQSettingsForInactive(current, identifier: identifier)
            },
            onSavePreset: { name, settings in
                audioEngine.settingsManager.createUserPreset(name: name, settings: settings)
            },
            onDeleteUserPreset: { id in
                audioEngine.settingsManager.deleteUserPreset(id: id)
            },
            onRenameUserPreset: { id, newName in
                audioEngine.settingsManager.updateUserPreset(id: id, name: newName)
            },
            isEQExpanded: expansionState.appID == displayableApp.id,
            onEQToggle: {
                toggleEQ(for: displayableApp.id, scrollProxy: scrollProxy)
            },
            sliderWidth: appSliderWidth,
            onTogglePin: {
                audioEngine.unpinApp(identifier)
            },
            isFocused: hasKeyboardEngaged && selectedRow == .app(persistenceID: displayableApp.id)
        )
        .id(PopupKeyboardNavModel.RowID.app(persistenceID: displayableApp.id))
    }

    /// Toggle EQ panel for an app (shared between active and inactive rows).
    /// SwiftUI owns interruption and reversal; there is no timing-based input lock.
    private func toggleEQ(for appID: String, scrollProxy: ScrollViewProxy) {
        withAnimation(structuralExpansionAnimation) {
            let isExpanding = expansionState.toggleApp(appID)
            if isExpanding {
                scrollProxy.scrollTo(PopupKeyboardNavModel.RowID.app(persistenceID: appID), anchor: .top)
            }
        }
    }

    private static let rowReorderGlide =
        Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.32)

    private static let deviceReorderDragPrefix = "finetune-device:"
    private static let appReorderDragPrefix = "finetune-app:"

    private static func deviceReorderPayload(_ uid: String) -> String {
        deviceReorderDragPrefix + uid
    }

    private static func appReorderPayload(_ identifier: String) -> String {
        appReorderDragPrefix + identifier
    }

    private static func reorderIdentifier(from items: [String], prefix: String) -> String? {
        guard let payload = items.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        let identifier = String(payload.dropFirst(prefix.count))
        return identifier.isEmpty ? nil : identifier
    }

    @discardableResult
    private func reorderEditableDevice(deviceUID: String, to targetIndex: Int) -> Bool {
        let currentIdentifiers = editableDeviceOrder.map(\.uid)
        guard let reorderedIdentifiers = DeviceReorderAccessibility.reorderedIdentifiers(
            currentIdentifiers,
            moving: deviceUID,
            to: targetIndex
        ) else {
            return false
        }

        let devicesByUID = Dictionary(
            uniqueKeysWithValues: editableDeviceOrder.map { ($0.uid, $0) }
        )
        let reorderedDevices = reorderedIdentifiers.compactMap { devicesByUID[$0] }
        guard reorderedDevices.count == editableDeviceOrder.count else { return false }

        withAnimation(accessibilityReduceMotion ? nil : Self.rowReorderGlide) {
            editableDeviceOrder = reorderedDevices
        }
        return true
    }

    // MARK: - Device Priority Edit

    private func toggleDevicePriorityEdit() {
        if isEditingDevicePriority {
            // Exiting edit mode: persist to the correct priority list and
            // collapse any expanded device detail (the inline body only lives
            // inside edit mode, so it must collapse when the mode does).
            let editMode = exitEditModeSaving()
            if editMode == .input {
                updateSortedInputDevices()
            } else {
                updateSortedDevices()
            }
        } else {
            // Entering edit mode: use the full (unfiltered) device list so hidden devices are also shown.
            let editMode = PopupDevicePriorityEditMode(showingInputDevices: showingInputDevices)
            editableDeviceOrder = editMode.isInput
                ? audioEngine.prioritySortedInputDevices
                : audioEngine.prioritySortedOutputDevices
            devicePriorityEditSession.begin(showingInputDevices: showingInputDevices)
        }
    }

    /// Persists the editable order to the correct priority list, preserving disconnected device positions.
    private func persistEditableOrder(for editMode: PopupDevicePriorityEditMode) {
        let connectedOrder = editableDeviceOrder.map(\.uid)
        if editMode.isInput {
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
    private func exitEditModeSaving() -> PopupDevicePriorityEditMode? {
        guard let editMode = devicePriorityEditSession.exit() else { return nil }
        persistEditableOrder(for: editMode)
        expansionState.collapseDevice()
        return editMode
    }

    private func resetToRootPage() {
        exitEditModeSaving()
        expansionState.reset()
        showingInputDevices = false
    }

    /// Merges device list changes into `editableDeviceOrder` while preserving the user's reordering.
    /// Existing devices are refreshed (CoreAudio may reassign AudioDeviceIDs), removed devices are
    /// dropped, and reconnecting devices are inserted at their saved priority position.
    private func mergeDeviceChanges(from latest: [AudioDevice]) {
        let latestByUID = Dictionary(latest.map { ($0.uid, $0) }, uniquingKeysWith: { _, new in new })
        let priorityOrder = devicePriorityEditMode?.isInput == true
            ? audioEngine.settingsManager.inputDevicePriorityOrder
            : audioEngine.settingsManager.devicePriorityOrder

        withAnimation(accessibilityReduceMotion ? nil : .easeOut(duration: 0.15)) {
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
            appPersistenceIDs: audioEngine.displayableApps.map(\.id),
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
            applyAppVolumeStep(
                currentGain: audioEngine.getVolumeForInactive(identifier: persistenceID),
                currentMute: audioEngine.getMuteForInactive(identifier: persistenceID),
                delta: delta,
                setGain: { audioEngine.setVolumeForInactive(identifier: persistenceID, to: $0) },
                setMute: { audioEngine.setMuteForInactive(identifier: persistenceID, to: $0) }
            )
            return .handled
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
            let current = audioEngine.getMuteForInactive(identifier: persistenceID)
            AppVolumeCommandPlan.muteToggle(
                currentGain: audioEngine.getVolumeForInactive(identifier: persistenceID),
                isMuted: current
            ).apply(
                setVolume: { audioEngine.setVolumeForInactive(identifier: persistenceID, to: $0) },
                setMute: { audioEngine.setMuteForInactive(identifier: persistenceID, to: $0) }
            )
            return .handled
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
            withAnimation(structuralExpansionAnimation) {
                _ = expansionState.toggleApp(persistenceID)
            }
            return .handled
        }
    }

    private func selectDeviceTab(showInput: Bool) {
        guard let transition = devicePriorityEditSession.selectTab(
            currentlyShowingInput: showingInputDevices,
            requestedShowInput: showInput
        ) else { return }

        if let editModeToExit = transition.editModeToExit {
            persistEditableOrder(for: editModeToExit)
            expansionState.collapseDevice()
        }

        withAnimation(accessibilityReduceMotion ? nil : .easeOut(duration: 0.15)) {
            showingInputDevices = transition.showInput
        }
    }

    private func toggleDeviceTab() {
        selectDeviceTab(showInput: !showingInputDevices)
    }

    /// Activates an app, bringing it to foreground and restoring minimized windows
    private func activateApp(pid: pid_t, bundleID: String?) {
        // Step 1: Always activate via NSRunningApplication (reliable for non-minimized)
        let runningApp = NSWorkspace.shared.runningApplications.first { $0.processIdentifier == pid }
        runningApp?.activate()

        // Step 2: Try to restore minimized windows via AppleScript
        if let bundleID = bundleID {
            // reopen + activate restores minimized windows for most apps
            let script = NSAppleScript(source: """
                tell application id "\(bundleID)"
                    reopen
                    activate
                end tell
                """)
            script?.executeAndReturnError(nil)
        }
    }
}

private struct AddApplicationsButton: View {
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @State private var isTooltipVisible = false
    @State private var tooltipTask: Task<Void, Never>?

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .frame(
                    minWidth: DesignTokens.Dimensions.minTouchTarget,
                    minHeight: DesignTokens.Dimensions.minTouchTarget
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add Applications")
        .onHover(perform: updateHover)
        .overlay(alignment: .bottomTrailing) {
            Text("Add Applications")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                .fixedSize()
                .opacity(isTooltipVisible ? 1 : 0)
                .scaleEffect(isTooltipVisible ? 1 : 0.96, anchor: .topTrailing)
                .blur(radius: isTooltipVisible || reduceMotion ? 0 : 4)
                .offset(y: 30)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .zIndex(10)
        .onDisappear {
            tooltipTask?.cancel()
        }
    }

    private func updateHover(_ hovering: Bool) {
        isHovered = hovering
        tooltipTask?.cancel()

        if hovering {
            tooltipTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled, isHovered else { return }
                if reduceMotion {
                    isTooltipVisible = true
                } else {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isTooltipVisible = true
                    }
                }
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isTooltipVisible = false
            }
        }
    }
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
                    isPinned: false,
                    onTogglePin: {}
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
