import SwiftMocking
import XCTest

final class StoreTests: XCTestCase {
    func testRegisterUsesStubbedPrices() {
        let mock = MockPricingService()
        let store = Store(pricingService: mock)

        when(mock.price(for: "apple")).thenReturn(13)
        when(mock.price(for: "banana")).thenReturn(17)

        store.register("apple")
        store.register("banana")

        XCTAssertEqual(store.prices["apple"], 13)
        XCTAssertEqual(store.prices["banana"], 17)

        verify(mock.price(for: .any)).called(2)
    }
}
