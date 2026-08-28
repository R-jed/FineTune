import AppKit
import Combine
import SwiftUI

/// FineTune-owned menu-bar scene. It keeps SwiftUI scene integration for Settings
/// while owning the status item and popup window directly.
struct FineTuneMenuBarExtra<Content: View>: Scene {
    @MainActor
    private final class State: ObservableObject {
        var statusItem: FineTuneMenuBarStatusItem?
    }

    @StateObject private var state = State()
    @Binding private var isInserted: Bool

    private let title: String
    private let image: NSImage
    private let popupController: MenuBarPopupController
    private let iconCoordinator: MenuBarIconCoordinator
    private let content: () -> Content

    init(
        _ title: String,
        image: NSImage,
        isInserted: Binding<Bool>,
        popupController: MenuBarPopupController,
        iconCoordinator: MenuBarIconCoordinator,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.image = image
        self._isInserted = isInserted
        self.popupController = popupController
        self.iconCoordinator = iconCoordinator
        self.content = content
    }

    var body: some Scene {
        if let statusItem = state.statusItem {
            statusItem.isVisible = isInserted
        } else {
            let window = FineTuneMenuBarPopupWindow(title: title, content: content)
            let statusItem = FineTuneMenuBarStatusItem(
                title: title,
                image: image,
                isInserted: $isInserted,
                window: window
            )
            state.statusItem = statusItem
            popupController.attach { [weak statusItem] in
                statusItem?.toggleWindow()
            }
            if let button = statusItem.button {
                iconCoordinator.attach(statusButton: button)
            }
        }

        return Settings {}
            .onChange(of: isInserted) { _, newValue in
                state.statusItem?.isVisible = newValue
            }
    }
}

@MainActor
class FineTuneMenuBarPopupPanel: NSPanel {}

@MainActor
final class FineTuneMenuBarPopupWindow<Content: View>: FineTuneMenuBarPopupPanel {
    weak var statusItem: FineTuneMenuBarStatusItem?

    private let content: () -> Content

    private var rootView: some View {
        content()
            .edgesIgnoringSafeArea(.all)
            .fixedSize()
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            self.reportContentSize(geometry.size)
                        }
                        .onChange(of: geometry.size) { _, newSize in
                            self.reportContentSize(newSize)
                        }
                }
            }
    }

    private lazy var hostingView: NSHostingView<some View> = {
        let view = NSHostingView(rootView: rootView)
        view.sizingOptions = []
        view.isVerticalContentSizeConstraintActive = false
        view.isHorizontalContentSizeConstraintActive = false
        return view
    }()

    init(title: String, content: @escaping () -> Content) {
        self.content = content

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled, .nonactivatingPanel, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.title = title
        isMovable = false
        isMovableByWindowBackground = false
        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        animationBehavior = .none
        collectionBehavior = [.stationary, .moveToActiveSpace, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        installSurface()
        setContentSize(hostingView.fittingSize)
    }

    private func installSurface() {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            hostingView.translatesAutoresizingMaskIntoConstraints = true
            hostingView.frame = glass.bounds
            hostingView.autoresizingMask = [.width, .height]
            glass.contentView = hostingView
            contentView = glass
        } else {
            let material = NSVisualEffectView()
            material.material = .popover
            material.blendingMode = .behindWindow
            material.state = .active
            material.translatesAutoresizingMaskIntoConstraints = true

            hostingView.translatesAutoresizingMaskIntoConstraints = false
            material.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: material.topAnchor),
                hostingView.trailingAnchor.constraint(equalTo: material.trailingAnchor),
                hostingView.bottomAnchor.constraint(equalTo: material.bottomAnchor),
                hostingView.leadingAnchor.constraint(equalTo: material.leadingAnchor)
            ])
            contentView = material
        }
    }

    private func reportContentSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        Task { @MainActor [weak self] in
            // SwiftUI structural transitions already produce intermediate geometry.
            // Follow that geometry directly instead of adding a second AppKit
            // interpolation owner for the same state change.
            self?.statusItem?.setWindowFrame(size: size, animate: false)
        }
    }
}

@MainActor
final class FineTuneMenuBarStatusItem: NSObject, NSWindowDelegate {
    private static let windowBorderSize: CGFloat = 2

    let window: NSWindow
    private let statusItem: NSStatusItem
    private var statusItemVisibilityObservation: NSKeyValueObservation?
    private var globalEventMonitor: Any?
    private var isDismissing = false

    @Binding private var isInserted: Bool

    var button: NSStatusBarButton? { statusItem.button }

    var isVisible: Bool {
        get { statusItem.isVisible }
        set { statusItem.isVisible = newValue }
    }

    init<Content: View>(
        title: String,
        image: NSImage,
        isInserted: Binding<Bool>,
        window: FineTuneMenuBarPopupWindow<Content>
    ) {
        self._isInserted = isInserted
        self.window = window
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        statusItem.behavior = .removalAllowed
        statusItem.isVisible = isInserted.wrappedValue
        statusItem.button?.setAccessibilityTitle(title)
        statusItem.button?.image = image
        statusItem.button?.target = self
        statusItem.button?.action = #selector(didPressStatusBarButton(_:))
        statusItem.button?.sendAction(on: [.leftMouseDown])

        window.statusItem = self
        window.delegate = self

        statusItemVisibilityObservation = statusItem.observe(\.isVisible, options: [.new]) { [weak self] _, change in
            guard let newValue = change.newValue else { return }
            Task { @MainActor [weak self] in
                self?.isInserted = newValue
            }
        }
    }

    @objc private func didPressStatusBarButton(_ sender: NSStatusBarButton) {
        guard NSApp.currentEvent?.modifierFlags.contains(.command) != true else { return }
        toggleWindow()
    }

    func toggleWindow() {
        if window.isVisible {
            dismissWindow()
        } else {
            showWindow()
        }
    }

    func showWindow() {
        guard !window.isVisible else { return }
        isDismissing = false
        setWindowFrame()
        window.alphaValue = 1
        DistributedNotificationCenter.default().post(name: .fineTuneBeginMenuTracking, object: nil)
        window.makeKeyAndOrderFront(nil)
    }

    func dismissWindow() {
        guard window.isVisible, !isDismissing else { return }
        isDismissing = true
        DistributedNotificationCenter.default().post(name: .fineTuneEndMenuTracking, object: nil)

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            finishDismissal()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                self?.finishDismissal()
            }
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        statusItem.button?.highlight(true)
        startGlobalEventMonitor()
    }

    func windowDidResignKey(_ notification: Notification) {
        stopGlobalEventMonitor()
        dismissWindow()
    }

    func setWindowFrame(size: CGSize? = nil, animate: Bool = false) {
        guard let statusItemWindow = statusItem.button?.window else {
            if let size {
                window.setFrame(NSRect(origin: window.frame.origin, size: size), display: true)
            }
            window.center()
            return
        }

        let newFrame = FineTuneMenuBarFrameCalculator.frame(
            statusItemFrame: statusItemWindow.frame,
            contentSize: size ?? window.frame.size,
            screenVisibleFrame: statusItemWindow.screen?.visibleFrame,
            borderSize: Self.windowBorderSize
        )

        guard newFrame != window.frame else { return }
        let shouldAnimate = animate && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        window.setFrame(newFrame, display: true, animate: shouldAnimate)
    }

    private func finishDismissal() {
        window.orderOut(nil)
        window.alphaValue = 1
        statusItem.button?.highlight(false)
        isDismissing = false
    }

    private func startGlobalEventMonitor() {
        guard globalEventMonitor == nil else { return }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.window.isKeyWindow else { return }
                self.window.resignKey()
            }
        }
    }

    private func stopGlobalEventMonitor() {
        guard let globalEventMonitor else { return }
        NSEvent.removeMonitor(globalEventMonitor)
        self.globalEventMonitor = nil
    }
}

enum FineTuneMenuBarFrameCalculator {
    static func frame(
        statusItemFrame: CGRect,
        contentSize: CGSize,
        screenVisibleFrame: CGRect?,
        borderSize: CGFloat = 2
    ) -> CGRect {
        var frame = CGRect(origin: statusItemFrame.origin, size: contentSize)
        frame.origin.y -= frame.height
        frame.origin.x -= borderSize

        guard let visibleFrame = screenVisibleFrame else { return frame }

        if frame.maxX > visibleFrame.maxX {
            frame.origin.x = statusItemFrame.maxX - frame.width + borderSize
        }
        if frame.minX < visibleFrame.minX {
            frame.origin.x = visibleFrame.minX + borderSize
        }
        return frame
    }
}

private extension Notification.Name {
    static let fineTuneBeginMenuTracking = Notification.Name("com.apple.HIToolbox.beginMenuTrackingNotification")
    static let fineTuneEndMenuTracking = Notification.Name("com.apple.HIToolbox.endMenuTrackingNotification")
}
