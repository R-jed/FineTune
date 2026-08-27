// FineTune/Views/Components/AppReorderAccessibility.swift
import SwiftUI

/// Bridges the app-list ordering policy into SwiftUI accessibility actions.
///
/// The controller reads the latest visible order when VoiceOver invokes an
/// action, then delegates the mutation back to AudioEngine. The pure
/// AppListPresentationOrder seam decides whether a direction is currently
/// available, while AppListCoordinator independently rejects cross-group
/// writes as a second fail-close boundary.
@MainActor
final class AppReorderAccessibilityController {
    private let audioEngine: AudioEngine

    init(audioEngine: AudioEngine) {
        self.audioEngine = audioEngine
    }

    func target(for identifier: String, direction: Int) -> String? {
        let orderedIdentifiers = audioEngine.displayableApps.map(\.id)
        let pinnedIdentifiers = Set(
            orderedIdentifiers.filter { audioEngine.settingsManager.isPinned($0) }
        )

        return AppListPresentationOrder.reorderTarget(
            for: identifier,
            direction: direction,
            orderedIdentifiers: orderedIdentifiers,
            pinnedIdentifiers: pinnedIdentifiers
        )
    }

    func move(_ identifier: String, direction: Int) {
        guard let targetIdentifier = target(for: identifier, direction: direction) else {
            return
        }
        audioEngine.moveApp(identifier, to: targetIdentifier)
    }
}

private struct AppReorderAccessibilityControllerKey: EnvironmentKey {
    static let defaultValue: AppReorderAccessibilityController? = nil
}

extension EnvironmentValues {
    var appReorderAccessibilityController: AppReorderAccessibilityController? {
        get { self[AppReorderAccessibilityControllerKey.self] }
        set { self[AppReorderAccessibilityControllerKey.self] = newValue }
    }
}

private struct AppReorderAccessibilityModifier: ViewModifier {
    @Environment(\.appReorderAccessibilityController) private var controller

    let identifier: String

    @ViewBuilder
    func body(content: Content) -> some View {
        let canMoveUp = controller?.target(for: identifier, direction: -1) != nil
        let canMoveDown = controller?.target(for: identifier, direction: 1) != nil

        if canMoveUp && canMoveDown {
            accessibleLabel(content)
                .accessibilityAction(named: Text("Move Up")) {
                    controller?.move(identifier, direction: -1)
                }
                .accessibilityAction(named: Text("Move Down")) {
                    controller?.move(identifier, direction: 1)
                }
        } else if canMoveUp {
            accessibleLabel(content)
                .accessibilityAction(named: Text("Move Up")) {
                    controller?.move(identifier, direction: -1)
                }
        } else if canMoveDown {
            accessibleLabel(content)
                .accessibilityAction(named: Text("Move Down")) {
                    controller?.move(identifier, direction: 1)
                }
        } else {
            accessibleLabel(content)
        }
    }

    private func accessibleLabel(_ content: Content) -> some View {
        content.accessibilityElement(children: .combine)
    }
}

extension View {
    func appReorderAccessibility(identifier: String) -> some View {
        modifier(AppReorderAccessibilityModifier(identifier: identifier))
    }
}
