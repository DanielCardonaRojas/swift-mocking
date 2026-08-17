func testStubOrdering() {
    let mock = MockCalculator()

    let odd = ArgMatcher<Int>.any(that: { $0 % 2 == 1 })

    // Specific matchers first...
    when(mock.calculate(a: odd, b: odd)).thenReturn { a, b in a * b }
    // ...broadest fallback last.
    when(mock.calculate(a: .any, b: .any)).thenReturn { a, b in a + b }

    XCTAssertEqual(mock.calculate(a: 3, b: 3), 9, "both odd — multiplied")
    XCTAssertEqual(mock.calculate(a: 3, b: 4), 7, "mixed — added")
}
