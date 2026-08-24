func testChargeFailsForLargeAmounts() throws {
    let mock = MockPaymentService()

    // Stub the failure path with .thenThrow, the happy path with .thenReturn.
    when(mock.charge(amountCents: .greaterThan(1000)))
        .thenThrow(PaymentError(code: 42))
    when(mock.charge(amountCents: .lessThan(1000))).thenReturn("ok")

    _ = try? mock.charge(amountCents: 5000)
    _ = try? mock.charge(amountCents: 10)
}
