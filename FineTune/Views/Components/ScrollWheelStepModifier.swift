import AppKit
import SwiftUI

struct ScrollWheelStepModifier<V: BinaryFloatingPoint>: ViewModifier {
    @Binding var value: V
    let range: ClosedRange<V>
    let sensitivity: V
    let requiresOptionModifier: Bool

    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if hovering {
                    install()
                } else {
                    uninstall()
                }
            }
            .onDisappear { uninstall() }
    }

    private func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard ScrollWheelStep.shouldAdjust(
                requiresOptionModifier: requiresOptionModifier,
                modifierFlags: event.modifierFlags
            ) else {
                return event
            }

            ScrollWheelStep.apply(
                event: event,
                value: &value,
                sensitivity: sensitivity,
                in: range
            )
            return nil
        }
    }

    private func uninstall() {
        if let token = monitor {
            NSEvent.removeMonitor(token)
        }
        monitor = nil
    }
}

extension View {
    /// Smooth wheel adjustment. Callers inside a scrolling list can require
    /// Option so ordinary scrolling continues through to the surrounding view.
    func scrollWheelStep<V: BinaryFloatingPoint>(
        _ value: Binding<V>,
        in range: ClosedRange<V>,
        requiresOptionModifier: Bool = false
    ) -> some View {
        let span = range.upperBound - range.lowerBound
        return modifier(
            ScrollWheelStepModifier(
                value: value,
                range: range,
                sensitivity: span / 200,
                requiresOptionModifier: requiresOptionModifier
            )
        )
    }
}
