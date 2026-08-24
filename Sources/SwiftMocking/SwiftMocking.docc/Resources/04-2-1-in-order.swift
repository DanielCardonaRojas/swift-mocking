import SwiftMocking
import Testing

@Mockable
protocol AnalyticsService {
    func logEvent(_ name: String) -> Void
}
