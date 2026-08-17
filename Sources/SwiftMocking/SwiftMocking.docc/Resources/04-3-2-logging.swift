func testInvocationLogging() {
    let mock = MockPricingService()
    mock.isLoggingEnabled = true

    // Console: each invocation is printed as it happens.
    _ = mock.price(for: "apple")
    _ = mock.price(for: "banana")
}
