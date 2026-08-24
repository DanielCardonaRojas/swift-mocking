import SwiftMocking
import Testing

@Suite
struct OrderServiceTests {
    @Test
    func anyVersusExact() {
        let mock = MockOrderService()
