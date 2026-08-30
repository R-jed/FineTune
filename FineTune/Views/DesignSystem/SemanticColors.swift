import AppKit
import SwiftUI

extension DesignTokens {
    // MARK: - Colors

    enum Colors {
        // MARK: Text (Vibrancy-aware)

        /// Primary text - automatically adapts for vibrancy on materials
        static let textPrimary: Color = .primary

        /// Secondary text - slightly muted, still vibrant
        static let textSecondary: Color = .secondary

        /// Tertiary text - for less important content
        static let textTertiary = Color(nsColor: .tertiaryLabelColor)

        /// Quaternary text - very subtle
        static let textQuaternary = Color(nsColor: .quaternaryLabelColor)

        // MARK: Interactive

        /// Enabled controls should retain full semantic label contrast on glass.
        static let interactiveDefault: Color = .primary

        /// Hovered interactive element color
        static let interactiveHover: Color = .primary.opacity(0.9)

        /// Active/pressed interactive element color
        static let interactiveActive: Color = .primary

        /// System accent color for selections and primary actions
        static let accentPrimary: Color = .accentColor

        /// Mute button active (muted state) - red for visibility
        static let mutedIndicator = Color(nsColor: .systemRed).opacity(0.85)

        /// Default device indicator - uses accent color
        static let defaultDevice: Color = .accentColor

        // MARK: Separators & Borders

        /// System separator color - adapts to appearance
        static let separator = Color(nsColor: .separatorColor)

        /// Subtle border for glass elements
        static let glassBorder = Color(nsColor: .separatorColor).opacity(0.3)

        /// Hover-state border
        static let glassBorderHover = Color(nsColor: .separatorColor).opacity(0.5)

        // MARK: Slider

        /// Slider track background (unfilled) - visible on glass
        static let sliderTrack: Color = .primary.opacity(0.15)

        /// Slider filled track - uses accent color
        static let sliderFill: Color = .accentColor

        /// Slider thumb
        static let sliderThumb: Color = .white

        /// Unity marker on slider
        static let unityMarker: Color = .primary.opacity(0.5)

        // MARK: Control Elements

        /// EQ/slider thumb background
        static let thumbBackground: Color = .white

        /// EQ/slider thumb center dot
        static let thumbDot: Color = .black.opacity(0.7)

        // MARK: Glass Effects

        /// Exact light-mode popup wash used by upstream FineTune 2285279d.
        /// Applied only in Light appearance; Dark keeps the native glass surface
        /// un-tinted so the current dark visual remains unchanged.
        static let popupLightOverlay = Color(nsColor: NSColor.white.withAlphaComponent(0.50))

        /// Recessed panel background (EQ panel). Light mode is nearly flush
        /// with the surrounding glass; opaque cards do the floating instead.
        static let recessedBackground = dynamicColor(
            name: "recessedBackground",
            light: NSColor.black.withAlphaComponent(0.04),
            dark: NSColor.black.withAlphaComponent(0.3)
        )

        // MARK: Menu/Picker

        /// Menu button background
        static let menuBackground: Color = .clear

        /// Menu button border. Light bumped for visible edge on glass surface.
        static let menuBorder = dynamicColor(
            name: "menuBorder",
            light: NSColor.black.withAlphaComponent(0.18),
            dark: NSColor.white.withAlphaComponent(0.12)
        )

        /// Menu button border on hover. Strong contrast in light mode so the
        /// hover state reads at a glance.
        static let menuBorderHover = dynamicColor(
            name: "menuBorderHover",
            light: NSColor.black.withAlphaComponent(0.32),
            dark: NSColor.white.withAlphaComponent(0.25)
        )

        /// Picker background
        static let pickerBackground: Color = .primary.opacity(0.08)

        /// Picker hover
        static let pickerHover: Color = .primary.opacity(0.12)

        // MARK: Hover & Glass Surface

        /// Hover background for tappable rows. With flat-row design (no
        /// resting fill or border), this is the primary "this row is active"
        /// affordance, so it needs to read clearly without being heavy.
        /// Light bumped from 0.08 → 0.115 to remain unambiguous on the
        /// new whiter glass without competing with the selected-row
        /// indicator. Matches the macOS-native System Settings pattern.
        static let hoverSurface = dynamicColor(
            name: "hoverSurface",
            light: NSColor.black.withAlphaComponent(0.115),
            dark: NSColor.white.withAlphaComponent(0.07)
        )

        /// Default row fill. Transparent — rows blend with the popup
        /// material at rest, like System Settings / Notification Center.
        /// Hover reveals `hoverSurface` as the meaningful interaction signal.
        static let glassFill = dynamicColor(
            name: "glassFill",
            light: NSColor.clear,
            dark: NSColor.clear
        )

        /// Stronger glass-card fill for emphasised badges and sheet inserts
        /// (DEFAULT pill, AutoEQ search panel, device-detail sheet). Not used
        /// for default row backgrounds.
        static let glassFillStrong = dynamicColor(
            name: "glassFillStrong",
            light: NSColor.white.withAlphaComponent(0.85),
            dark: NSColor.white.withAlphaComponent(0.1)
        )

        /// Default row border. Transparent — flat rows have no resting edge.
        static let glassRowBorder = dynamicColor(
            name: "glassRowBorder",
            light: NSColor.clear,
            dark: NSColor.clear
        )

        /// Hovered row edge — soft hairline visible only when the row is
        /// being interacted with. Pairs with `hoverSurface` to define the
        /// active row.
        static let glassRowBorderHover = dynamicColor(
            name: "glassRowBorderHover",
            light: NSColor.black.withAlphaComponent(0.10),
            dark: NSColor.white.withAlphaComponent(0.15)
        )

        /// HUD panel hairline border (Tahoe + Classic).
        static let hudBorder = dynamicColor(
            name: "hudBorder",
            light: NSColor.black.withAlphaComponent(0.15),
            dark: NSColor.white.withAlphaComponent(0.08)
        )

        // MARK: Cards & Badges

        /// Lifted-card fill used by the EQ panel and Settings sections.
        /// Light reads as a white card on the popup glass; dark reads as
        /// a subtle translucent surface on the dark glass. Pairs with
        /// `eqCardBorder` for the hairline edge.
        static let eqCardBackground = dynamicColor(
            name: "eqCardBackground",
            light: NSColor.white.withAlphaComponent(0.78),
            dark: NSColor.white.withAlphaComponent(0.07)
        )

        /// Hairline border for the lifted card. Visible enough to define
        /// the edge, quiet enough to read as part of the glass family.
        static let eqCardBorder = dynamicColor(
            name: "eqCardBorder",
            light: NSColor.black.withAlphaComponent(0.06),
            dark: NSColor.white.withAlphaComponent(0.10)
        )

        /// Monochrome circular badge fill used on non-selected device rows.
        /// The selected state uses a `Color.accentColor` gradient inline in
        /// `DeviceBadge`; that does not need a token.
        static let deviceBadgeMonoFill = dynamicColor(
            name: "deviceBadgeMonoFill",
            light: NSColor.black.withAlphaComponent(0.10),
            dark: NSColor.white.withAlphaComponent(0.10)
        )

        /// Foreground color for the device-badge SF symbol on a non-selected
        /// row. Selected rows use white directly inside `DeviceBadge`.
        static let deviceBadgeMonoForeground = dynamicColor(
            name: "deviceBadgeMonoForeground",
            light: NSColor.black.withAlphaComponent(0.65),
            dark: NSColor.white.withAlphaComponent(0.70)
        )

        // MARK: Source Activity Meter

        /// Source meter green segments (bars 0-3, lower levels)
        static let vuGreen = Color(red: 0.20, green: 0.78, blue: 0.40)

        /// Source meter yellow segments (bars 4-5, higher levels)
        static let vuYellow = Color(red: 0.95, green: 0.75, blue: 0.20)

        /// Source meter orange segment (bar 6, near full scale)
        static let vuOrange = Color(red: 0.95, green: 0.50, blue: 0.20)

        /// Source meter red segment (bar 7, full-scale source activity)
        static let vuRed = Color(red: 0.90, green: 0.25, blue: 0.25)

        /// Source meter unlit bar color (matches sliderTrack for visual consistency)
        static let vuUnlit: Color = .primary.opacity(0.15)

        /// Source meter muted state
        static let vuMuted: Color = .primary.opacity(0.35)

        // MARK: AutoEQ

        /// AutoEQ empty-state dashed border. Light bumped so the dashed
        /// outline reads on a translucent panel.
        static let autoEQEmptyBorder = dynamicColor(
            name: "autoEQEmptyBorder",
            light: NSColor.black.withAlphaComponent(0.22),
            dark: NSColor.white.withAlphaComponent(0.1)
        )

        /// AutoEQ empty-state icon color. Light made darker so the icon is
        /// visible on a near-white background.
        static let autoEQEmptyIcon = dynamicColor(
            name: "autoEQEmptyIcon",
            light: NSColor(white: 0.45, alpha: 1.0),
            dark: NSColor(white: 0.267, alpha: 1.0)
        )

        /// AutoEQ toggle label text color (Correction / Preamp labels).
        static let autoEQToggleLabel = dynamicColor(
            name: "autoEQToggleLabel",
            light: NSColor.black.withAlphaComponent(0.65),
            dark: NSColor.white.withAlphaComponent(0.5)
        )

        // MARK: HUD

        /// Active dot in Tahoe HUD tick track
        static let hudDotActive: Color = .primary.opacity(0.85)

        /// Inactive dot in Tahoe HUD tick track
        static let hudDotInactive: Color = .primary.opacity(0.18)

        /// Active tile in Classic HUD segment row
        static let hudTileActive: Color = .primary.opacity(0.7)

        /// Inactive tile in Classic HUD segment row
        static let hudTileInactive: Color = .primary.opacity(0.2)
    }

}
