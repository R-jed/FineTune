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

extension Color {
    static var popupBackgroundOverlay: Color { DesignTokens.Colors.popupOverlay }
}

extension View {
    /// The menu-bar window now owns the single popup surface: Liquid Glass on
    /// macOS 26+ and one `.popover` material on older supported systems.
    /// Keep this source-compatible modifier as a content-only no-op so existing
    /// popup code cannot accidentally stack another material or fixed tint.
    func darkGlassBackground() -> some View {
        self
    }

    func eqCardBackground() -> some View {
        modifier(LiftedCardBackgroundModifier())
    }
}

struct LiftedCardBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.Dimensions.rowRadius)
                    .fill(DesignTokens.Colors.eqCardBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Dimensions.rowRadius)
                    .strokeBorder(DesignTokens.Colors.eqCardBorder, lineWidth: 0.5)
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
