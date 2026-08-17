import SwiftMocking
import XCTest

@Mockable
protocol AnalyticsService {
    func logEvent(_ name: String) -> Void
}
