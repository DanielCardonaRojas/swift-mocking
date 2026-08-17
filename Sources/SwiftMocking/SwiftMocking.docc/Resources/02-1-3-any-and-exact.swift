import SwiftMocking
import XCTest

final class OrderServiceTests: XCTestCase {
    func testAnyVersusExact() {
        let mock = MockOrderService()

        // The fallback: answers every call, whatever the amount.
        when(mock.discount(forAmountCents: .any)).thenReturn(100)
