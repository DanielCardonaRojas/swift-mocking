import SwiftMocking
import XCTest

@Mockable
protocol AnalyticsService {
    func logEvent(_ name: String) -> Void
}

final class CheckoutTests: XCTestCase {
    func testCheckoutOrder() {
        let pricing = MockPricingService()
        let analytics = MockAnalyticsService()

        when(pricing.price(for: .any)).thenReturn(13)
