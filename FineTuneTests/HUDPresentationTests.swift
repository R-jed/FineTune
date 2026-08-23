import Foundation
import Testing
@testable import FineTune

@Suite("HUD presentation")
struct HUDPresentationTests {
    private let locale = Locale(identifier: "en_AU")

    @Test("Device HUD announcements preserve current English semantics")
    func deviceAnnouncements() {
        #expect(
            HUDPresentation.deviceAnnouncement(
                deviceName: "AirPods Pro",
                sliderFraction: 0.5,
                mute: false,
                language: .english,
                baseLocale: locale
            ) == "AirPods Pro, volume 50 percent"
        )
        #expect(
            HUDPresentation.deviceAnnouncement(
                deviceName: "AirPods Pro",
                sliderFraction: 0.5,
                mute: true,
                language: .english,
                baseLocale: locale
            ) == "AirPods Pro, muted"
        )
        #expect(
            HUDPresentation.deviceAnnouncement(
                deviceName: "",
                sliderFraction: 0.25,
                mute: false,
                language: .english,
                baseLocale: locale
            ) == "Unknown device, volume 25 percent"
        )
    }

    @Test("Tahoe and Classic accessibility labels preserve current English semantics")
    func styleLabels() {
        #expect(
            HUDPresentation.tahoeAccessibilityLabel(
                deviceName: "Studio Display",
                sliderFraction: 0.5,
                mute: true,
                language: .english,
                baseLocale: locale
            ) == "Studio Display, muted, volume at 50 percent"
        )
        #expect(
            HUDPresentation.classicAccessibilityLabel(
                sliderFraction: 0.5,
                mute: false,
                language: .english,
                baseLocale: locale
            ) == "Volume 50 percent"
        )
        #expect(
            HUDPresentation.classicAccessibilityLabel(
                sliderFraction: 0.5,
                mute: true,
                language: .english,
                baseLocale: locale
            ) == "Muted"
        )
    }

    @Test("Per-app HUD announcements keep app names verbatim")
    func perAppAnnouncements() {
        #expect(
            HUDPresentation.perAppVolumeAnnouncement(
                title: "Music α",
                sliderFraction: 0.75,
                language: .english,
                baseLocale: locale
            ) == "Music α, volume 75 percent"
        )
        #expect(
            HUDPresentation.perAppMuteAnnouncement(
                title: "Music α",
                isMuted: false,
                language: .english,
                baseLocale: locale
            ) == "Music α, unmuted"
        )
        #expect(
            HUDPresentation.perAppNotControlledAnnouncement(
                title: "Music α",
                language: .english,
                baseLocale: locale
            ) == "Music α, not controlled by FineTune"
        )
        #expect(
            HUDPresentation.localizedAppNotControlledFallback(
                language: .english,
                baseLocale: locale
            ) == "FineTune isn't controlling this app yet"
        )
    }

    @Test("Percentages clamp to the HUD display range")
    func clampsPercentages() {
        #expect(
            HUDPresentation.perAppVolumeAnnouncement(
                title: "App",
                sliderFraction: 1.5,
                language: .english,
                baseLocale: locale
            ) == "App, volume 100 percent"
        )
        #expect(
            HUDPresentation.perAppVolumeAnnouncement(
                title: "App",
                sliderFraction: -0.5,
                language: .english,
                baseLocale: locale
            ) == "App, volume 0 percent"
        )
    }
}
