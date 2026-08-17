import SwiftMocking

@Mockable
protocol PricingService {
    func price(for item: String) -> Int
}
