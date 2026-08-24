import SwiftMocking

@Mockable
protocol Clock {
    static func now() -> Int
    static var timeZone: String { get }
}
