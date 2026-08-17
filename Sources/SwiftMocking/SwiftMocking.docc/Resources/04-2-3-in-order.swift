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

        // The system under test interleaves both dependencies.
        _ = pricing.price(for: "apple")
        analytics.logEvent("purchase")
        _ = pricing.price(for: "banana")
