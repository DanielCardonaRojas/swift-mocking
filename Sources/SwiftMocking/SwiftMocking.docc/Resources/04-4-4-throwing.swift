func testRefundFailsAsynchronously() async throws {
    let mock = MockPaymentService()

    when(mock.refund(id: .any)).thenThrow(PaymentError(code: 7))
    _ = try? await mock.refund(id: "order-1")

    // For async throwing methods, `throws` is itself awaited.
    await verify(mock.refund(id: .any)).throws(.error(PaymentError.self))

    verify(mock.refund(id: .any)).called(1)
}
