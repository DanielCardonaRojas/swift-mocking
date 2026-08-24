@Test
func stubOrdering() {
    let mock = MockCalculator()

    let odd = ArgMatcher<Int>.any(that: { $0 % 2 == 1 })
