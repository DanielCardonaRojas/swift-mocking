import SwiftMocking
import Testing

@Test
func customPrecedenceOverridesTheLadder() {
    let mock = MockRateService()
    let service: any RateService = mock

    // A predicate would normally rank 200 and lose to `.equal`'s 500.
    // Building the matcher by hand lets you choose its precedence.
    let roundNumbers = ArgMatcher<Int>(precedence: .customExtreme) {
        $0 % 100 == 0
    }

    when(mock.rate(forAmount: 500)).thenReturn("exact")       // 500
    when(mock.rate(forAmount: roundNumbers)).thenReturn("vip") // 999

    // 999 outranks 500, so the custom matcher answers.
    #expect(service.rate(forAmount: 500) == "vip")
}
