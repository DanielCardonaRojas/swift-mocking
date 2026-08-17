func testCapturedArguments() {
    let mock = MockOrderService()

    when(mock.validate(items: .any, coupon: .any)).thenReturn(true)
    _ = mock.validate(items: ["apple", "banana"], coupon: "SUMMER")
    _ = mock.validate(items: ["cherry"], coupon: nil)
