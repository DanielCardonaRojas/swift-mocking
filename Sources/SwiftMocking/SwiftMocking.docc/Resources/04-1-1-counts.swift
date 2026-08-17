func testCounts() {
    let mock = MockPricingService()

    when(mock.price(for: .any)).thenReturn(13)
    _ = mock.price(for: "apple")
    _ = mock.price(for: "banana")
