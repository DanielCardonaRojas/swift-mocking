@Test
func predicatesAndRanges() {
    let mock = MockOrderService()

    when(mock.discount(forAmountCents: .lessThan(100))).thenReturn(0)
    when(mock.discount(forAmountCents: .in(100...999))).thenReturn(50)
    when(mock.discount(forAmountCents: .greaterThan(999))).thenReturn(150)

    #expect(mock.discount(forAmountCents: 50) == 0)
    #expect(mock.discount(forAmountCents: 500) == 50)
    #expect(mock.discount(forAmountCents: 5000) == 150)
