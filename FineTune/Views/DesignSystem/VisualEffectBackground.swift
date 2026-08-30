// FineTune/Views/DesignSystem/VisualEffectBackground.swift
import SwiftUI
import AppKit

/// Legacy material primitive kept for previews and non-popup surfaces that may
/// still need an AppKit visual-effect view on older macOS releases.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

extension View {
    /// Restores the upstream FineTune 2285279d light popup surface exactly:
    /// an inner `.popover` visual-effect layer plus a 50% white wash. In Dark
    /// appearance this modifier is intentionally a no-op so the native
    /// `NSGlassEffectView(.regular)` host remains visually untouched.
    func originalLightPopupBackground() -> some View {
        modifier(OriginalLightPopupBackgroundModifier())
    }

    func eqCardBackground() -> some View {
        modifier(LiftedCardBackgroundModifier())
    }
}

private struct OriginalLightPopupBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    func body(content: Content) -> some View {
        if colorScheme == .light {
            content
                .background(DesignTokens.Colors.popupLightOverlay)
                .background(
                    VisualEffectBackground(
                        material: .popover,
                        blendingMode: .behindWindow
                    )
                )
        } else {
            content
        }
    }
}

struct LiftedCardBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.Dimensions.rowRadius)
                    .fill(DesignTokens.Surface.raised)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Dimensions.rowRadius)
                    .strokeBorder(DesignTokens.Stroke.raised, lineWidth: 0.5)
            }
            .shadow(
                color: Color.black.opacity(0.06),
                radius: 1.5,
                x: 0,
                y: 0.5
            )
    }
}

#Preview("Popup Content Layer") {
    VStack(spacing: 16) {
        Text("OUTPUT DEVICES")
            .sectionHeaderStyle()
        Text("Popup surface is supplied by the AppKit host")
            .foregroundStyle(.primary)
    }
    .padding(DesignTokens.Spacing.lg)
    .frame(width: 300)
    .background(VisualEffectBackground(material: .popover, blendingMode: .behindWindow))
    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Dimensions.cornerRadius))
}

#Preview("EQ Card - Lifted") {
    VStack(spacing: 8) {
        Text("EQ Card - Lifted")
            .foregroundStyle(.secondary)
        HStack {
            ForEach(0..<5) { _ in
                Rectangle()
                    .fill(.secondary.opacity(0.3))
                    .frame(width: 20, height: 60)
            }
        }
    }
    .padding()
    .eqCardBackground()
    .padding()
    .background(VisualEffectBackground(material: .popover, blendingMode: .behindWindow))
}
