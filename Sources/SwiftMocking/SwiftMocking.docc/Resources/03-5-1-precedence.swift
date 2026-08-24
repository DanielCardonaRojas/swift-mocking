import SwiftMocking

@Mockable
protocol RateService {
    func rate(forAmount amount: Int) -> String
    func fee(amount: Int, currency: String) -> String
}
