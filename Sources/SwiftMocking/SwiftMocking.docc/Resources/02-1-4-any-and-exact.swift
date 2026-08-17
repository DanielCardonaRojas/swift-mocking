import SwiftMocking
import XCTest

final class OrderServiceTests: XCTestCase {
    func testAnyVersusExact() {
        let mock = MockOrderService()

        // The fallback: answers every call, whatever the amount.
        when(mock.discount(forAmountCents: .any)).thenReturn(100)

        // More specific: wins for this exact amount.
        when(mock.discount(forAmountCents: 999)).thenReturn(200)

        XCTAssertEqual(mock.discount(forAmountCents: 999), 200)
        XCTAssertEqual(mock.discount(forAmountCents: 199), 100)
