// FineTune/Views/MenuBar/MenuBarIconState.swift
// Value types for the menu bar icon. Bucket thresholds mirror the visible
// percentages used by TahoeStyleHUD and ClassicStyleHUD.
// The AppKit NSImage bridge lives in MenuBarIconImage+NSImage.swift.

import Foundation

nonisolated enum MenuBarIconImage: Equatable {
    case systemSymbol(String)
    case asset(String)
}

nonisolated enum VolumeBucket: Equatable {
    case zero
    case low
    case mid
    case high

    static func bucket(for volume: Float) -> VolumeBucket {
        guard volume.isFinite else { return .zero }
        let clamped = max(0, min(1, volume))
        let percent = Int((clamped * 100).rounded())
        switch percent {
        case 0:       return .zero
        case 1...33:  return .low
        case 34...66: return .mid
        default:      return .high
        }
    }

    var symbolName: String {
        switch self {
        case .zero: return "speaker.fill"
        case .low:  return "speaker.wave.1.fill"
        case .mid:  return "speaker.wave.2.fill"
        case .high: return "speaker.wave.3.fill"
        }
    }
}

nonisolated enum MenuBarIconState: Equatable {
    case speakerVolume(VolumeBucket)
    case speakerMuted
    case device(symbol: String)
    case staticBaseline(MenuBarIconImage)
    case deviceFlash(symbol: String)

    var image: MenuBarIconImage {
        switch self {
        case .speakerVolume(let bucket): return .systemSymbol(bucket.symbolName)
        case .speakerMuted:              return .systemSymbol("speaker.slash.fill")
        case .device(let symbol):        return .systemSymbol(symbol)
        case .staticBaseline(let image): return image
        case .deviceFlash(let symbol):   return .systemSymbol(symbol)
        }
    }
}

extension MenuBarIconState {
    /// `volume` is the same user-visible slider fraction used by the popup and HUD.
    static func baseline(
        style: MenuBarIconStyle,
        volume: Float,
        muted: Bool,
        deviceSymbol: String = MenuBarIconStyle.device.iconName
    ) -> MenuBarIconState {
        switch style {
        case .speaker:
            let presentation = VolumePresentationState(
                storedFraction: Double(volume),
                isMuted: muted,
                sourceIsActive: false
            )
            if presentation.displaysMuted {
                return .speakerMuted
            }
            return .speakerVolume(.bucket(for: Float(presentation.displayFraction)))
        case .device:
            return .device(symbol: deviceSymbol)
        case .default:
            return .staticBaseline(.asset("MenuBarIcon"))
        case .waveform:
            return .staticBaseline(.systemSymbol("waveform"))
        case .equalizer:
            return .staticBaseline(.systemSymbol("slider.vertical.3"))
        }
    }
}
