//
//  FluidMenuBarExtraWindow.swift
//  FluidMenuBarExtra
//
//  Created by Lukas Romsicki on 2022-12-16.
//  Copyright © 2022 Lukas Romsicki.
//

import AppKit
import SwiftUI

/// Keeps upstream FineTune's legacy `.popover` surface in Light appearance,
/// while preserving FineTune's native `NSGlassEffectView(.regular)` surface in
/// Dark appearance on macOS 26+. The same NSHostingView is re-parented between
/// surfaces so SwiftUI state and in-flight interactions keep their identity.
private final class FluidMenuBarExtraSurfaceView: NSView {
    private enum SurfaceKind: Equatable {
        case legacyPopover
        case nativeGlass
    }

    private let hostedView: NSView
    private var activeSurface: NSView?
    private var activeKind: SurfaceKind?

    init(hostedView: NSView) {
        self.hostedView = hostedView
        super.init(frame: .zero)
        autoresizingMask = [.width, .height]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateSurfaceIfNeeded()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateSurfaceIfNeeded()
    }

    private func updateSurfaceIfNeeded() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let desiredKind: SurfaceKind

        if #available(macOS 26.0, *), isDark {
            desiredKind = .nativeGlass
        } else {
            desiredKind = .legacyPopover
        }

        guard desiredKind != activeKind else { return }

        hostedView.removeFromSuperview()
        activeSurface?.removeFromSuperview()

        let surface: NSView
        switch desiredKind {
        case .legacyPopover:
            let visualEffectView = NSVisualEffectView()
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.material = .popover
            visualEffectView.translatesAutoresizingMaskIntoConstraints = true
            visualEffectView.addSubview(hostedView)

            NSLayoutConstraint.activate([
                hostedView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
                hostedView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
                hostedView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
                hostedView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor)
            ])

            surface = visualEffectView

        case .nativeGlass:
            guard #available(macOS 26.0, *) else { return }

            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = 12
            glass.tintColor = nil
            glass.translatesAutoresizingMaskIntoConstraints = true

            let glassContent = NSView()
            glassContent.translatesAutoresizingMaskIntoConstraints = true
            glass.contentView = glassContent
            glassContent.addSubview(hostedView)

            NSLayoutConstraint.activate([
                hostedView.topAnchor.constraint(equalTo: glassContent.topAnchor),
                hostedView.trailingAnchor.constraint(equalTo: glassContent.trailingAnchor),
                hostedView.bottomAnchor.constraint(equalTo: glassContent.bottomAnchor),
                hostedView.leadingAnchor.constraint(equalTo: glassContent.leadingAnchor)
            ])

            surface = glass
        }

        surface.frame = bounds
        surface.autoresizingMask = [.width, .height]
        addSubview(surface)
        activeSurface = surface
        activeKind = desiredKind
    }
}

/// A custom window configured to behave as closely to an `NSMenu` as possible.
///
/// `FluidMenuBarExtraWindow` listens for changes to the size of its content and
/// automatically adjusts its frame to match.
final class FluidMenuBarExtraWindow<Content: View>: NSPanel {
    private let content: () -> Content
    weak var statusItem: FluidMenuBarExtraStatusItem? = nil

    private var rootView: some View {
        content()
            .modifier(RootViewModifier(windowTitle: title))
            .onSizeUpdate { [weak self] size in
                self?.contentSizeDidUpdate(to: size)
            }
    }

    private lazy var hostingView: NSHostingView<some View> = {
        let view = NSHostingView(rootView: rootView)
        // Disable NSHostingView's default automatic sizing behavior.
        view.sizingOptions = []
        view.isVerticalContentSizeConstraintActive = false
        view.isHorizontalContentSizeConstraintActive = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var surfaceView = FluidMenuBarExtraSurfaceView(hostedView: hostingView)

    init(title: String,
         animation: NSWindow.AnimationBehavior = .none,
         content: @escaping () -> Content) {
        self.content = content

        super.init(
            contentRect: CGRect(x: 0, y: 0, width: 100, height: 100),
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
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        animationBehavior = animation
        collectionBehavior = [.stationary, .moveToActiveSpace, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        contentView = surfaceView
        setContentSize(hostingView.intrinsicContentSize)
    }

    private func contentSizeDidUpdate(to size: CGSize) {
        guard frame.size != size else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.statusItem?.setWindowFrame(size: size, animate: true)
        }
    }
}
