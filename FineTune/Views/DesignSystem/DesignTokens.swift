// FineTune/Views/DesignSystem/DesignTokens.swift
import AppKit
import Foundation
import SwiftUI

/// Namespace for FineTune's design-system primitives. Concrete token families
/// live in focused extension files so visual changes can evolve by semantic
/// layer without turning this file into a cross-component dumping ground.
enum DesignTokens {
    // MARK: - Internal helpers

    /// Builds a SwiftUI Color that resolves to `light` or `dark` based on the
    /// effective NSAppearance at draw time. SwiftUI re-resolves automatically
    /// when the appearance changes (system toggle or override change) because
    /// `Color(nsColor:)` preserves the underlying NSColor's adaptability.
    ///
    /// `name` is NSColor's caching key. Pass a unique name per token; two
    /// dynamic colors sharing a name silently resolve to the same instance.
    /// `DesignTokensDynamicResolutionTests` enforces uniqueness by asserting
    /// per-token RGBA values.
    static func dynamicColor(name: String, light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name(name)) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    // MARK: - Links

    enum Links {
        /// Financial support page (currently Ko-fi, URL is platform-agnostic in UI)
        static let support = URL(string: "https://ko-fi.com/ronitsingh10")!

        /// Project license on GitHub
        static let license = URL(string: "https://github.com/ronitsingh10/FineTune/blob/main/LICENSE")!
    }
}
