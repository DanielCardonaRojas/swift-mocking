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
