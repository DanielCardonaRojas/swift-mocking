import SwiftMocking
import Testing

@Mockable
protocol AnalyticsService {
    func logEvent(_ name: String) -> Void
}

@Suite
struct CheckoutTests {
    @Test
    func checkoutOrder() {
        let pricing = MockPricingService()
        let analytics = MockAnalyticsService()

        when(pricing.price(for: .any)).thenReturn(13)

        // The system under test interleaves both dependencies.
        _ = pricing.price(for: "apple")
        analytics.logEvent("purchase")
        _ = pricing.price(for: "banana")

        // Passes only because the calls above happened in this order.
        verifyInOrder {
            pricing.price(for: "apple")
            analytics.logEvent("purchase")
            pricing.price(for: "banana")
        }
    }
}
