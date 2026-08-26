// FineTuneTests/DeviceIconPickerTests.swift

import Testing
import Foundation
@testable import FineTune

@Suite("DeviceIconPicker highlight rule")
struct DeviceIconPickerTests {

    @Test("Override symbol is highlighted when set")
    func overrideHighlighted() {
        let symbol = DeviceIconPicker.highlightSymbol(
            currentOverride: "gamecontroller.fill", automaticIsSymbol: true, automaticSymbol: "headphones")
        #expect(symbol == "gamecontroller.fill")
    }

    @Test("Automatic suggested symbol is highlighted when no override")
    func automaticHighlighted() {
        let symbol = DeviceIconPicker.highlightSymbol(
            currentOverride: nil, automaticIsSymbol: true, automaticSymbol: "headphones")
        #expect(symbol == "headphones")
    }

    @Test("Nothing is highlighted when the automatic icon is a driver image")
    func driverImageHighlightsNothing() {
        let symbol = DeviceIconPicker.highlightSymbol(
            currentOverride: nil, automaticIsSymbol: false, automaticSymbol: "headphones")
        #expect(symbol == nil)
    }

    @Test("Search matches Simplified Chinese category titles")
    func localizedCategorySearch() {
        let locale = Locale(identifier: "zh-Hans")

        let headphoneSymbols = DeviceIconPicker.matchingEntries(query: "耳机", locale: locale).map(\.symbol)
        #expect(headphoneSymbols.contains("headphones"))
        #expect(headphoneSymbols.contains("airpodspro"))

        let microphoneSymbols = DeviceIconPicker.matchingEntries(query: "麦克风", locale: locale).map(\.symbol)
        #expect(microphoneSymbols.contains("mic"))

        let displaySymbols = DeviceIconPicker.matchingEntries(query: "显示器", locale: locale).map(\.symbol)
        #expect(displaySymbols.contains("display"))
    }

    @Test("Icon category resource follows the selected locale")
    func localizedCategoryResource() {
        guard let resource = DeviceIconPicker.localizedCategoryTitle(forSymbol: "headphones") else {
            Issue.record("Expected headphones to resolve to a localized icon category")
            return
        }

        let english = LocalizationContext(
            language: .english,
            baseLocale: Locale(identifier: "en_US")
        )
        let chinese = LocalizationContext(
            language: .simplifiedChinese,
            baseLocale: Locale(identifier: "en_US")
        )

        #expect(english.localized(resource) == "Headphones & Earbuds")
        #expect(chinese.localized(resource) == "耳机与耳塞")
    }
}

@Suite("DeviceIconPicker suggested composition")
struct DeviceIconPickerSuggestedTests {

    @Test("Leading symbol comes first and is not duplicated from shared")
    func leadingFirstAndDeduped() {
        let symbols = DeviceIconPicker.composeSuggested(
            leading: "mic", shared: ["headphones", "mic", "headset"])
        #expect(symbols == ["mic", "headphones", "headset"])
    }

    @Test("Nil leading returns the shared suggestions unchanged")
    func nilLeadingPassesThrough() {
        let shared = ["headphones", "hifispeaker.fill", "headset"]
        #expect(DeviceIconPicker.composeSuggested(leading: nil, shared: shared) == shared)
    }
}
