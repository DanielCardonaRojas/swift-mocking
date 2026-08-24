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

        store.register("apple")
        store.register("banana")

        #expect(store.prices["apple"] == 13)
        #expect(store.prices["banana"] == 17)
