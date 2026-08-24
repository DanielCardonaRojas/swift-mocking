@Test
func capturedArguments() {
    let mock = MockOrderService()

    when(mock.validate(items: .any, coupon: .any)).thenReturn(true)
    _ = mock.validate(items: ["apple", "banana"], coupon: "SUMMER")
    _ = mock.validate(items: ["cherry"], coupon: nil)

    // The matcher selects invocations; captured replays each one
    // with its concrete, fully typed arguments.
    verify(mock.validate(items: .any, coupon: .equal("SUMMER")))
        .captured { items, coupon in
            #expect(items == ["apple", "banana"])
            #expect(coupon == "SUMMER")
        }
}
