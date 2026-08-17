import SwiftMocking
import XCTest

final class StoreTests: XCTestCase {
    func testRegisterUsesStubbedPrices() {
        let mock = MockPricingService()
        let store = Store(pricingService: mock)

        when(mock.price(for: "apple")).thenReturn(13)
        when(mock.price(for: "banana")).thenReturn(17)
