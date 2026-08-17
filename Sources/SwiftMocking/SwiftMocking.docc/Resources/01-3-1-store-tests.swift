import SwiftMocking
import XCTest

final class StoreTests: XCTestCase {
    func testRegisterUsesStubbedPrices() {
        let mock = MockPricingService()
        let store = Store(pricingService: mock)
