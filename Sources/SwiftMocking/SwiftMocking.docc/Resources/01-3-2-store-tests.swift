import SwiftMocking
import Testing

@Suite
struct StoreTests {
    @Test
    func registerUsesStubbedPrices() {
        let mock = MockPricingService()
        let store = Store(pricingService: mock)

        when(mock.price(for: "apple")).thenReturn(13)
        when(mock.price(for: "banana")).thenReturn(17)
