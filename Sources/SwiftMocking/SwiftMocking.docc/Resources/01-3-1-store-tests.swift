import SwiftMocking
import Testing

@Suite
struct StoreTests {
    @Test
    func registerUsesStubbedPrices() {
        let mock = MockPricingService()
        let store = Store(pricingService: mock)
