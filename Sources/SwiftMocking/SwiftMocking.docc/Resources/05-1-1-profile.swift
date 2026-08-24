import SwiftMocking

@Mockable
protocol UserProfile {
    func displayName() -> String
    func retryLimit() -> Int
    func isPremium() -> Bool
}
