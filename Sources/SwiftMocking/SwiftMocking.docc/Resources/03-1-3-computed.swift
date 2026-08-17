func testComputedReturn() {
    let mock = MockCalculator()

    // a and b are real Ints — no casting, ever.
    when(mock.calculate(a: .any, b: .any)).thenReturn { a, b in
        a * b
    }

    XCTAssertEqual(mock.calculate(a: 6, b: 7), 42)
}
