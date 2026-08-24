func testChargeFailsForLargeAmounts() throws {
    let mock = MockPaymentService()

    // Stub the failure path with .thenThrow, the happy path with .thenReturn.
    when(mock.charge(amountCents: .greaterThan(1000)))
        .thenThrow(PaymentError(code: 42))
    when(mock.charge(amountCents: .lessThan(1000))).thenReturn("ok")

    _ = try? mock.charge(amountCents: 5000)
    _ = try? mock.charge(amountCents: 10)

    // .throws() asserts some error was thrown by matching calls.
    verify(mock.charge(amountCents: .greaterThan(1000))).throws()

    // Narrow it: any error, or one of a specific type.
    verify(mock.charge(amountCents: .greaterThan(1000))).throws(.anyError())
    verify(mock.charge(amountCents: .greaterThan(1000)))
        .throws(.error(PaymentError.self))

    // Counting still works alongside throwing assertions.
    verify(mock.charge(amountCents: .any)).called(2)
}
