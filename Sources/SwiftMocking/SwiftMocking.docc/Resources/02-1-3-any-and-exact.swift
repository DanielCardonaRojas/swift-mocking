import SwiftMocking
import Testing

@Suite
struct OrderServiceTests {
    @Test
    func anyVersusExact() {
        let mock = MockOrderService()

        // The fallback: answers every call, whatever the amount.
        when(mock.discount(forAmountCents: .any)).thenReturn(100)
