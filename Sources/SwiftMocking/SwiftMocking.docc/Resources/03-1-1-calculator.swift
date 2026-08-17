import SwiftMocking

@Mockable
protocol Calculator {
    func calculate(a: Int, b: Int) -> Int
}
