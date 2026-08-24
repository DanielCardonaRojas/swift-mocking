@Test
func expectedCountMessage() {
    let mock = MockPricingService()

    when(mock.price(for: .any)).thenReturn(13)
    _ = mock.price(for: "apple")
    _ = mock.price(for: "banana")

    // Fails at this line with:
    //   Unfulfilled call count. Actual: 2
    verify(mock.price(for: .any)).called(4)
}
