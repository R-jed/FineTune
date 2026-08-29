import AppKit
import AudioToolbox
import Observation
import os

@MainActor
final class MenuBarIconCoordinator: MediaKeyIconFlashing {
    private let deviceVolumeMonitor: DeviceVolumeMonitor
    private let deviceProvider: any AudioDeviceProviding
    private let settings: SettingsManager
    private let logger = Logger(subsystem: "com.finetuneapp.FineTune", category: "MenuBarIconCoordinator")

    private weak var cachedButton: NSStatusBarButton?
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

    func start() {
        guard !started else { return }
        started = true
        lastObservedDeviceID = deviceVolumeMonitor.defaultDeviceID
        attemptInitialApply(retriesLeft: 20)
        scheduleApplyTracking()
        scheduleDeviceChangeTracking()
    }

    func stop() {
        flashWorkItem?.cancel()
        flashWorkItem = nil
        cachedButton = nil
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
        guard let button = resolveButton() else { return }
        let state = computeState()
        guard let image = state.image.nsImage() else { return }
        addFadeTransition(to: button)
        button.image = image
    }

    private func attemptInitialApply(retriesLeft: Int) {
        if resolveButton() != nil {
            apply()
            return
        }
        guard retriesLeft > 0 else {
            logger.error("Menu bar button not found after 20 tries; keeping the launch icon until the next state change")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.attemptInitialApply(retriesLeft: retriesLeft - 1)
        }
    }

    private func resolveButton() -> NSStatusBarButton? {
        if let cachedButton { return cachedButton }
        for window in NSApp.windows {
            guard let contentView = window.contentView else { continue }
            if let button = findStatusBarButton(in: contentView, matching: "FineTune") {
                button.wantsLayer = true
                cachedButton = button
                return button
            }
        }
        return nil
    }

    private func findStatusBarButton(in view: NSView, matching title: String) -> NSStatusBarButton? {
        if let button = view as? NSStatusBarButton, button.accessibilityTitle() == title {
            return button
        }
        for subview in view.subviews {
            if let match = findStatusBarButton(in: subview, matching: title) {
                return match
            }
        }
        return nil
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
