import SwiftMocking

@Mockable
protocol FeatureFlags {
    var isEnabled: Bool { get set }
    var retryCount: Int { get set }
}
