func testStubOrdering() {
    let mock = MockCalculator()

    let odd = ArgMatcher<Int>.any(that: { $0 % 2 == 1 })

    // Specific matchers first...
    when(mock.calculate(a: odd, b: odd)).thenReturn { a, b in a * b }
    // ...broadest fallback last.
    when(mock.calculate(a: .any, b: .any)).thenReturn { a, b in a + b }
