@Test
func counts() {
    let mock = MockPricingService()

    when(mock.price(for: .any)).thenReturn(13)
    _ = mock.price(for: "apple")
    _ = mock.price(for: "banana")

    verify(mock.price(for: .any)).called(2)      // exactly twice
    verify(mock.price(for: "apple")).called()    // at least once (the default)
    verify(mock.price(for: "apple")).called(1)   // exactly once — be explicit

    // Any ArgMatcher<Int> works as a count matcher.
    verify(mock.price(for: .any)).called(.greaterThan(1))
    verify(mock.price(for: .any)).called(.lessThan(5))
    verify(mock.price(for: .any)).called(.in(1...3))
    verify(mock.price(for: .any)).called(.between(2, 4))
}
