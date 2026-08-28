import AppKit
import AudioToolbox
import Observation

@MainActor
final class MenuBarIconCoordinator: MediaKeyIconFlashing {
    private let deviceVolumeMonitor: DeviceVolumeMonitor
    private let deviceProvider: any AudioDeviceProviding
    private let settings: SettingsManager

    private weak var statusButton: NSStatusBarButton?
    private var flashWorkItem: DispatchWorkItem?
    private var flashActiveSymbol: String?
    private var lastObservedDeviceID: AudioDeviceID?
    private var started = false

    init(
        deviceVolumeMonitor: DeviceVolumeMonitor,
        deviceProvider: any AudioDeviceProviding,
        settings: SettingsManager
    ) {
        self.deviceVolumeMonitor = deviceVolumeMonitor
        self.deviceProvider = deviceProvider
        self.settings = settings
    }

    /// Attaches the real status-bar button owned by FineTune's menu-bar Scene.
    /// Safe before or after start; attaching after start immediately renders state.
    func attach(statusButton: NSStatusBarButton) {
        self.statusButton = statusButton
        statusButton.wantsLayer = true
        if started {
            apply()
        }
    }

    func start() {
        guard !started else { return }
        started = true
        lastObservedDeviceID = deviceVolumeMonitor.defaultDeviceID
        apply()
        scheduleApplyTracking()
        scheduleDeviceChangeTracking()
    }

    func stop() {
        flashWorkItem?.cancel()
        flashWorkItem = nil
        statusButton = nil
    }

    func flashDevice() {
        let symbol = currentDeviceSymbol()
        let alreadyShowingSame = flashActiveSymbol == symbol
        flashActiveSymbol = symbol
        if !alreadyShowingSame {
            apply()
        }

        flashWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.flashActiveSymbol = nil
            self.apply()
        }
        flashWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1, execute: item)
    }

    private func computeState() -> MenuBarIconState {
        if let symbol = flashActiveSymbol {
            return .deviceFlash(symbol: symbol)
        }
        let id = deviceVolumeMonitor.defaultDeviceID
        let storedVolume = deviceVolumeMonitor.storedOutputVolume(for: id)
        let tier = deviceVolumeMonitor.outputVolumeBackend(for: id)
        let displayFraction = Float(
            VolumeMapping.sliderFraction(forSystemGain: storedVolume, tier: tier)
        )
        let muted = deviceVolumeMonitor.muteStates[id] ?? false
        return MenuBarIconState.baseline(
            style: settings.appSettings.menuBarIconStyle,
            volume: displayFraction,
            muted: muted,
            deviceSymbol: currentDeviceSymbol()
        )
    }

    private func currentDeviceSymbol() -> String {
        MenuBarDeviceIconResolver.resolveSymbol(
            priorityOrder: settings.devicePriorityOrder,
            outputDevices: deviceProvider.outputDevices,
            defaultDeviceID: deviceVolumeMonitor.defaultDeviceID,
            overrideForUID: { [settings] in settings.getDeviceIconOverride(for: $0) }
        )
    }

    private func apply() {
        guard let statusButton else { return }
        let state = computeState()
        guard let image = state.image.nsImage() else { return }
        addFadeTransition(to: statusButton)
        statusButton.image = image
    }

    private func scheduleApplyTracking() {
        withObservationTracking {
            let id = deviceVolumeMonitor.defaultDeviceID
            _ = deviceVolumeMonitor.volumes[id]
            _ = deviceVolumeMonitor.muteStates[id]
            _ = settings.appSettings.menuBarIconStyle
            _ = settings.appSettings.hudStyle
            _ = settings.devicePriorityOrder
            _ = settings.deviceIconOverrides
            _ = deviceProvider.outputDevices
        } onChange: { [weak self] in
            MainActor.assumeIsolated { [weak self] in
                self?.scheduleApplyTracking()
            }
            Task { @MainActor [weak self] in
                self?.apply()
            }
        }
    }

    private func scheduleDeviceChangeTracking() {
        withObservationTracking {
            _ = deviceVolumeMonitor.defaultDeviceID
        } onChange: { [weak self] in
            MainActor.assumeIsolated { [weak self] in
                self?.scheduleDeviceChangeTracking()
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let newID = self.deviceVolumeMonitor.defaultDeviceID
                if let previous = self.lastObservedDeviceID,
                   previous != newID,
                   newID.isValid {
                    self.flashDevice()
                }
                self.lastObservedDeviceID = newID
            }
        }
    }

    private func addFadeTransition(to button: NSStatusBarButton) {
        let transition = CATransition()
        transition.type = .fade
        transition.duration = 0.18
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        button.layer?.add(transition, forKey: "iconFade")
    }
}
