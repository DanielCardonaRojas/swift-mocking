@Test
func refundFailsAsynchronously() async throws {
    let mock = MockPaymentService()

    when(mock.refund(id: .any)).thenThrow(PaymentError(code: 7))
    _ = try? await mock.refund(id: "order-1")

    verify(mock.refund(id: .any)).didThrow(.error(PaymentError.self))

    verify(mock.refund(id: .any)).called(1)
}
