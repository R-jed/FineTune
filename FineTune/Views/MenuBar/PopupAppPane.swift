import AppKit
import SwiftUI

/// Renders the running-App portion of the popup. High-frequency VU sampling is
/// isolated inside `LiveVUMeter`; the parent owns expansion/reorder mutations
/// and supplies only the presentation snapshot and actions required here.
struct PopupAppPane: View {
    static let groupHeaderExtent: CGFloat = 18

    private enum AppPresentationSection: Hashable {
        case pinned
        case applications
    }

    private enum AppPresentationItem: Identifiable {
        enum ID: Hashable {
            case header(AppPresentationSection)
            case app(String)
        }

        case header(AppPresentationSection)
        case app(DisplayableApp)

        var id: ID {
            switch self {
            case .header(let section):
                return .header(section)
            case .app(let displayableApp):
                return .app(displayableApp.id)
            }
        }
    }

    @Bindable var audioEngine: AudioEngine
    @Bindable var deviceVolumeMonitor: DeviceVolumeMonitor

    let permission: AudioRecordingPermission
    let apps: [DisplayableApp]
    let pinnedIdentifiers: Set<String>
    let outputDevices: [AudioDevice]
    let isPopupVisible: Bool
    let expandedAppID: String?
    let sliderWidth: CGFloat
    let draggedAppID: String?
    let draggedAppOffset: CGFloat
    let focusedRow: PopupKeyboardNavModel.RowID?
    let contentGutter: CGFloat
    let appSelectionError: LocalizedStringResource?

    let onEQToggle: (String) -> Void
    let onTogglePin: (String) -> Void
    let onAddApplications: () -> Void
    let onReorderChanged: (String, CGFloat) -> Void
    let onReorderEnded: (String) -> Void
    let canReorder: (String, Int) -> Bool
    let onAccessibleReorder: (String, Int) -> Void

    @State private var scrollPosition = ScrollPosition(edge: .top)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            SectionHeader(title: "Apps")
            Spacer()
            AddApplicationsButton(action: onAddApplications)
        }
        .padding(.bottom, DesignTokens.Spacing.xs)

        if let appSelectionError {
            Text(appSelectionError)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(.red)
                .padding(.bottom, DesignTokens.Spacing.xs)
        }

        if permission.status != .authorized {
            PermissionBannerView(permission: permission)
        } else if apps.isEmpty {
            emptyState
        } else {
            ScrollView {
                appRows
                    .padding(.trailing, contentGutter)
            }
            .scrollPosition($scrollPosition)
            .scrollIndicators(.visible)
            .frame(height: viewportHeight)
            .onChange(of: expandedAppID) { _, appID in
                guard let appID else { return }
                withAnimation(reduceMotion ? nil : DesignTokens.Animation.structural) {
                    scrollPosition.scrollTo(
                        id: PopupKeyboardNavModel.RowID.app(persistenceID: appID),
                        anchor: .top
                    )
                }
            }
        }
    }

    private var emptyState: some View {
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

    private var viewportHeight: CGFloat {
        let collapsedRowHeight = DesignTokens.Dimensions.rowContentHeight + 12
        let groupHeadersHeight = Self.groupHeaderExtent * 2
        if expandedAppID != nil {
            return collapsedRowHeight * 6 + groupHeadersHeight
        }
        return collapsedRowHeight * CGFloat(min(apps.count, 6)) + groupHeadersHeight
    }

    private var appRows: some View {
        let presets = audioEngine.settingsManager.getUserPresets()
        let pinnedApps = apps.filter { pinnedIdentifiers.contains($0.id) }
        let applications = apps.filter { !pinnedIdentifiers.contains($0.id) }
        let presentationItems: [AppPresentationItem] =
            [.header(.pinned)]
            + pinnedApps.map(AppPresentationItem.app)
            + [.header(.applications)]
            + applications.map(AppPresentationItem.app)

        return LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(presentationItems) { item in
                switch item {
                case .header(.pinned):
                    appGroupLabel("Pinned")
                case .header(.applications):
                    appGroupLabel("Applications")
                case .app(let displayableApp):
                    appRow(displayableApp, userPresets: presets)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .scrollTargetLayout()
    }

    private func appGroupLabel(_ title: LocalizedStringResource) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .padding(.leading, DesignTokens.Spacing.sm)
            .frame(
                maxWidth: .infinity,
                minHeight: Self.groupHeaderExtent,
                maxHeight: Self.groupHeaderExtent,
                alignment: .leading
            )
    }

    @ViewBuilder
    private func appRow(
        _ displayableApp: DisplayableApp,
        userPresets: [UserEQPreset]
    ) -> some View {
        Group {
            switch displayableApp {
            case .active(let app):
                activeAppRow(
                    app: app,
                    displayableApp: displayableApp,
                    userPresets: userPresets
                )
            case .pinnedInactive(let info):
                inactiveAppRow(
                    info: info,
                    displayableApp: displayableApp,
                    userPresets: userPresets
                )
            }
        }
        .accessibilityActions {
            if canReorder(displayableApp.id, -1) {
                Button("Move Up") {
                    onAccessibleReorder(displayableApp.id, -1)
                }
            }
            if canReorder(displayableApp.id, 1) {
                Button("Move Down") {
                    onAccessibleReorder(displayableApp.id, 1)
                }
            }
        }
    }

    @ViewBuilder
    private func activeAppRow(
        app: AudioApp,
        displayableApp: DisplayableApp,
        userPresets: [UserEQPreset]
    ) -> some View {
        if let deviceUID = audioEngine.getDeviceUID(for: app) {
            AppRow(
                app: app,
                volume: audioEngine.getVolume(for: app),
                getAudioLevel: { audioEngine.getAudioLevel(for: app) },
                isMeterActive: isPopupVisible,
                devices: outputDevices,
                deviceIconOverrides: audioEngine.settingsManager.deviceIconOverrides,
                selectedDeviceUID: deviceUID,
                selectedDeviceUIDs: audioEngine.getSelectedDeviceUIDs(for: app),
                isFollowingDefault: audioEngine.isFollowingDefault(for: app),
                defaultDeviceUID: deviceVolumeMonitor.defaultDeviceUID,
                deviceSelectionMode: audioEngine.getDeviceSelectionMode(for: app),
                isMuted: audioEngine.getMute(for: app),
                boost: audioEngine.getBoost(for: app),
                onBoostChange: { boost in
                    audioEngine.setBoost(for: app, to: boost)
                },
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
                isEQExpanded: expandedAppID == displayableApp.id,
                onEQToggle: {
                    onEQToggle(displayableApp.id)
                },
                isPinned: pinnedIdentifiers.contains(displayableApp.id),
                onTogglePin: {
                    onTogglePin(displayableApp.id)
                },
                sliderWidth: sliderWidth,
                isReordering: draggedAppID == displayableApp.id,
                reorderOffset: draggedAppID == displayableApp.id ? draggedAppOffset : 0,
                onReorderChanged: { rawTranslation in
                    onReorderChanged(displayableApp.id, rawTranslation)
                },
                onReorderEnded: {
                    onReorderEnded(displayableApp.id)
                },
                isFocused: focusedRow == .app(persistenceID: displayableApp.id)
            )
            .id(PopupKeyboardNavModel.RowID.app(persistenceID: displayableApp.id))
        }
    }

    private func inactiveAppRow(
        info: PinnedAppInfo,
        displayableApp: DisplayableApp,
        userPresets: [UserEQPreset]
    ) -> some View {
        let identifier = info.persistenceIdentifier
        return InactiveAppRow(
            appInfo: info,
            icon: displayableApp.icon,
            volume: audioEngine.getVolumeForInactive(identifier: identifier),
            devices: outputDevices,
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
            onDeviceSelected: { uid in
                audioEngine.setDeviceRoutingForInactive(identifier: identifier, deviceUID: uid)
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
            onUserPresetSelected: { preset in
                var current = audioEngine.getEQSettingsForInactive(identifier: identifier)
                current.bandGains = preset.settings.bandGains
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
            isEQExpanded: expandedAppID == identifier,
            onEQToggle: {
                onEQToggle(identifier)
            },
            sliderWidth: sliderWidth,
            isPinned: pinnedIdentifiers.contains(identifier),
            onTogglePin: {
                onTogglePin(identifier)
            },
            isReordering: draggedAppID == identifier,
            reorderOffset: draggedAppID == identifier ? draggedAppOffset : 0,
            onReorderChanged: { rawTranslation in
                onReorderChanged(identifier, rawTranslation)
            },
            onReorderEnded: {
                onReorderEnded(identifier)
            },
            isFocused: focusedRow == .app(persistenceID: identifier)
        )
        .id(PopupKeyboardNavModel.RowID.app(persistenceID: identifier))
    }

    private func activateApp(pid: pid_t, bundleID: String?) {
        let runningApp = NSWorkspace.shared.runningApplications.first { $0.processIdentifier == pid }
        runningApp?.activate()

        if let bundleID {
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

/// App visibility management used by the Output management page. Kept beside
/// `PopupAppPane` because both surfaces share App identity/presentation rules,
/// while ignore/unignore mutations remain delegated to `AudioEngine`.
struct PopupAppVisibilityPane: View {
    @Bindable var audioEngine: AudioEngine

    private let columns = [
        GridItem(.flexible(), spacing: DesignTokens.Spacing.xs),
        GridItem(.flexible(), spacing: DesignTokens.Spacing.xs)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            SectionHeader(title: "Apps")

            let visibleApps = audioEngine.displayableApps
            if !visibleApps.isEmpty {
                LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.xs) {
                    ForEach(visibleApps) { displayableApp in
                        AppManagementRow(
                            icon: displayableApp.icon,
                            name: displayableApp.displayName,
                            isIgnored: false,
                            onToggleVisibility: {
                                switch displayableApp {
                                case .active(let app): audioEngine.ignoreApp(app)
                                case .pinnedInactive(let info): audioEngine.ignoreApp(info)
                                }
                            }
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

                LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.xs) {
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
}
