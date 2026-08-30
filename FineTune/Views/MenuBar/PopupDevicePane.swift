import AudioToolbox
import SwiftUI

/// Renders the device portion of the menu-bar popup. The parent owns page,
/// expansion, and reorder mutations; this view owns only device presentation so
/// device-state changes do not force the App pane's layout code to participate.
struct PopupDevicePane: View {
    @Bindable var audioEngine: AudioEngine
    @Bindable var deviceVolumeMonitor: DeviceVolumeMonitor

    let direction: PopupAudioDirection
    let isManaging: Bool
    let sortedOutputDevices: [AudioDevice]
    let sortedInputDevices: [AudioDevice]
    let editableDeviceOrder: [AudioDevice]
    let pairedDevices: [PairedBluetoothDevice]
    let isBluetoothOn: Bool
    let expansionState: PopupExpansionState
    let reorderDragState: ContinuousReorderDragState
    let autoEQImportError: LocalizedStringResource?
    let focusedRow: PopupKeyboardNavModel.RowID?

    let onImportAutoEQ: (String) -> Void
    let onToggleDeviceExpansion: (String) -> Void
    let onReorderChanged: (String, CGFloat) -> Void
    let onReorderEnded: (String) -> Void
    let onReorder: (String, Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if isManaging {
                managementRows
            } else if direction.isInput {
                ForEach(sortedInputDevices) { device in
                    standardInputDeviceRow(device)
                }
            } else {
                ForEach(sortedOutputDevices) { device in
                    standardOutputDeviceRow(device)
                }
            }
        }
    }

    @ViewBuilder
    private var managementRows: some View {
        let defaultDeviceID = direction.isInput
            ? deviceVolumeMonitor.defaultInputDeviceID
            : deviceVolumeMonitor.defaultDeviceID

        ForEach(Array(editableDeviceOrder.enumerated()), id: \.element.uid) { index, device in
            editableDeviceRow(device: device, index: index, defaultDeviceID: defaultDeviceID)
        }

        if !direction.isInput {
            pairedOutputRows
        }
    }

    @ViewBuilder
    private var pairedOutputRows: some View {
        if !isBluetoothOn {
            Text("Turn on Bluetooth to connect devices")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, DesignTokens.Spacing.xs)
        } else {
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
            isFocused: focusedRow == .device(uid: device.uid),
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
            onAutoEQImport: { onImportAutoEQ(device.uid) },
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
            isFocused: focusedRow == .device(uid: device.uid),
            iconOverrideSymbol: audioEngine.settingsManager.getDeviceIconOverride(for: device.uid)
        )
        .id(PopupKeyboardNavModel.RowID.device(uid: device.uid))
    }

    @ViewBuilder
    private func editableDeviceRow(
        device: AudioDevice,
        index: Int,
        defaultDeviceID: AudioDeviceID
    ) -> some View {
        let isDeviceHidden = !direction.isInput
            && audioEngine.settingsManager.isOutputDeviceHidden(device.uid)

        DeviceEditRow(
            device: device,
            iconOverrideSymbol: audioEngine.settingsManager.getDeviceIconOverride(for: device.uid),
            priorityIndex: index,
            isDefault: device.id == defaultDeviceID,
            isInputDevice: direction.isInput,
            deviceCount: editableDeviceOrder.count,
            isExpanded: expansionState.deviceUID == device.uid,
            isHidden: isDeviceHidden,
            isReordering: reorderDragState.draggedID == device.uid,
            reorderOffset: reorderDragState.draggedID == device.uid
                ? reorderDragState.effectiveTranslation
                : 0,
            onReorderChanged: { rawTranslation in
                onReorderChanged(device.uid, rawTranslation)
            },
            onReorderEnded: {
                onReorderEnded(device.uid)
            },
            onReorder: { newIndex in
                onReorder(device.uid, newIndex)
            },
            onToggleExpand: direction.isInput ? nil : {
                onToggleDeviceExpansion(device.uid)
            },
            onToggleHidden: direction.isInput ? nil : {
                audioEngine.settingsManager.toggleOutputDeviceHidden(uid: device.uid)
            },
            onIconSelect: direction.isInput ? nil : { symbol in
                audioEngine.settingsManager.setDeviceIconOverride(for: device.uid, to: symbol)
            },
            expandedContent: {
                if !direction.isInput && expansionState.deviceUID == device.uid {
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
}
