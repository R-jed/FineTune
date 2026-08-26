import Testing
@testable import FineTune

@Suite("AutoEQ catalog refresh state")
struct AutoEQFetcherStateTests {
    @Test("Refresh failure keeps a usable cached catalog loaded")
    func cachedCatalogSurvivesRefreshFailure() {
        let state = AutoEQFetcher.catalogStateAfterRefreshFailure(
            hasExistingCatalog: true,
            message: "Network error"
        )

        #expect(state == .loaded)
    }

    @Test("Refresh failure surfaces an error without a usable catalog")
    func missingCatalogSurfacesRefreshFailure() {
        let state = AutoEQFetcher.catalogStateAfterRefreshFailure(
            hasExistingCatalog: false,
            message: "Network error"
        )

        #expect(state == .error("Network error"))
    }
}
