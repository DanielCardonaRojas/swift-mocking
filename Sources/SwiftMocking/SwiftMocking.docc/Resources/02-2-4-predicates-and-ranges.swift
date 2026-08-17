func testPredicatesAndRanges() {
    let mock = MockOrderService()

    when(mock.discount(forAmountCents: .lessThan(100))).thenReturn(0)
    when(mock.discount(forAmountCents: .in(100...999))).thenReturn(50)
    when(mock.discount(forAmountCents: .greaterThan(999))).thenReturn(150)

    XCTAssertEqual(mock.discount(forAmountCents: 50), 0)
    XCTAssertEqual(mock.discount(forAmountCents: 500), 50)
    XCTAssertEqual(mock.discount(forAmountCents: 5000), 150)

    // Any predicate you can express as a closure becomes a matcher.
    let roundAmounts = ArgMatcher<Int>.any(that: { $0.isMultiple(of: 100) })
    verify(mock.discount(forAmountCents: roundAmounts)).called(2)

    // Collections match by count: at most three items.
    verify(mock.validate(items: .hasCount(in: ...3), coupon: .any)).neverCalled()
}
