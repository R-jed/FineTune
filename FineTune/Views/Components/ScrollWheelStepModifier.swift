import AppKit
import SwiftUI

struct ScrollWheelStepModifier<V: BinaryFloatingPoint>: ViewModifier {
    @Binding var value: V
    let range: ClosedRange<V>
    let sensitivity: V

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
            // Normal wheel/trackpad scrolling belongs to the surrounding list.
            // Require Option as an explicit intent signal before consuming the event.
            guard ScrollWheelStep.shouldAdjust(modifierFlags: event.modifierFlags) else {
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
    /// Option + scroll adjusts the hovered value. Ordinary scrolling is passed
    /// through to the surrounding ScrollView.
    func scrollWheelStep<V: BinaryFloatingPoint>(
        _ value: Binding<V>,
        in range: ClosedRange<V>
    ) -> some View {
        let span = range.upperBound - range.lowerBound
        return modifier(ScrollWheelStepModifier(value: value, range: range, sensitivity: span / 200))
    }
}
