import SwiftMocking
import XCTest

final class OrderServiceTests: XCTestCase {
    func testAnyVersusExact() {
        let mock = MockOrderService()
