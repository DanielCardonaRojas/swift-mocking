import SwiftMocking
import Testing

@Test
func reportsInsufficientFunds() throws {
    let mock = MockPaymentService()
    when(mock.charge(amountCents: .any)).thenThrow(PaymentError(code: 42))

    let service: any PaymentService = mock

    // Swift Testing asserts thrown errors at the call site with
    // `#expect(throws:)` — the counterpart to XCTAssertThrowsError.
    #expect(throws: PaymentError.self) {
        _ = try service.charge(amountCents: 5000)
    }

    // And SwiftMocking asserts it from the mock's side.
    verify(mock.charge(amountCents: .any)).throws(.error(PaymentError.self))
}
