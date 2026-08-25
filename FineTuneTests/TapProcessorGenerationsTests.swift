// FineTuneTests/TapProcessorGenerationsTests.swift

import Testing
@testable import FineTune

@Suite("Tap processor generations")
struct TapProcessorGenerationsTests {

    @Test("promotion preserves each callback's captured processor generation")
    func promotionPreservesCapturedGenerations() {
        let generations = TapProcessorGenerations()
        let primaryCallbackState = generations.primary
        let secondaryCallbackState = generations.secondary

        generations.promoteSecondary()

        #expect(generations.primary === secondaryCallbackState)
        #expect(generations.primary !== primaryCallbackState)
        #expect(generations.secondary !== secondaryCallbackState)
        #expect(primaryCallbackState !== generations.primary)
        #expect(secondaryCallbackState === generations.primary)
    }

    @Test("reset isolates a later activation from callbacks of the old generation")
    func resetCreatesFreshGenerations() {
        let generations = TapProcessorGenerations()
        let oldPrimaryCallbackState = generations.primary
        let oldSecondaryCallbackState = generations.secondary

        generations.reset()

        #expect(generations.primary !== oldPrimaryCallbackState)
        #expect(generations.secondary !== oldSecondaryCallbackState)
        #expect(generations.primary !== generations.secondary)
    }

    @Test("resetSecondary replaces only the secondary generation")
    func resetSecondaryPreservesPrimary() {
        let generations = TapProcessorGenerations()
        let primary = generations.primary
        let secondary = generations.secondary

        generations.resetSecondary()

        #expect(generations.primary === primary)
        #expect(generations.secondary !== secondary)
    }

    @Test("primary replacement leaves an old callback bound to its old generation")
    func replacePrimaryPreservesOldCallbackState() {
        let generations = TapProcessorGenerations()
        let oldPrimaryCallbackState = generations.primary
        let replacement = TapProcessorState()

        generations.replacePrimary(with: replacement)

        #expect(generations.primary === replacement)
        #expect(generations.primary !== oldPrimaryCallbackState)
        #expect(oldPrimaryCallbackState !== replacement)
    }
}
