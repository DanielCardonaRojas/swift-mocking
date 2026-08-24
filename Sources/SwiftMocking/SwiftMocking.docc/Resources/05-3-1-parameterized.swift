import SwiftMocking
import Testing

// One test, run once per argument pair.
@Test(arguments: [("apple", 13), ("banana", 17)])
func pricesEachItem(item: String, expected: Int) {
    let mock = MockPricingService()

    // `item` is a runtime value, not a literal — so the literal-to-matcher
    // sugar doesn't apply and you spell the matcher explicitly.
    when(mock.price(for: .equal(item))).thenReturn(expected)

    let service: any PricingService = mock
    #expect(service.price(for: item) == expected)

    verify(mock.price(for: .equal(item))).called(1)
}
