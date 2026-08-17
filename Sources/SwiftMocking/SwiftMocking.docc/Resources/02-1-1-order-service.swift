import SwiftMocking

@Mockable
protocol OrderService {
    func discount(forAmountCents amount: Int) -> Int
    func validate(items: [String], coupon code: String?) -> Bool
}
