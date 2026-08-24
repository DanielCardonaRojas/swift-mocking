func testCounts() {
    let mock = MockPricingService()

    when(mock.price(for: .any)).thenReturn(13)
    _ = mock.price(for: "apple")
    _ = mock.price(for: "banana")

    verify(mock.price(for: .any)).called(2)      // exactly twice
    verify(mock.price(for: "apple")).called()    // exactly once (the default)

    verify(mock.price(for: "cherry")).neverCalled()

    let untouched = MockPricingService()
    verifyZeroInteractions(untouched)            // no calls of any kind
}
