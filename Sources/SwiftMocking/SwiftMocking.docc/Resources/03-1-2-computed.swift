@Test
func computedReturn() {
    let mock = MockCalculator()

    // a and b are real Ints — no casting, ever.
    when(mock.calculate(a: .any, b: .any)).thenReturn { a, b in
        a * b
    }
