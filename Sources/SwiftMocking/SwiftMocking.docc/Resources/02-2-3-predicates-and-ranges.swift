func testPredicatesAndRanges() {
    let mock = MockOrderService()

    when(mock.discount(forAmountCents: .lessThan(100))).thenReturn(0)
    when(mock.discount(forAmountCents: .in(100...999))).thenReturn(50)
    when(mock.discount(forAmountCents: .greaterThan(999))).thenReturn(150)

    XCTAssertEqual(mock.discount(forAmountCents: 50), 0)
    XCTAssertEqual(mock.discount(forAmountCents: 500), 50)
    XCTAssertEqual(mock.discount(forAmountCents: 5000), 150)
