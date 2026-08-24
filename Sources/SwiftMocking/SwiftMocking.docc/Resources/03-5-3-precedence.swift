import SwiftMocking
import Testing

@Test
func mostSpecificMatcherAnswersTheCall() {
    let mock = MockRateService()
    let service: any RateService = mock

    // Three stubs on the same method, deliberately registered
    // broadest-first. Precedence — not order — decides which answers.
    when(mock.rate(forAmount: .any)).thenReturn("any")               //   0
    when(mock.rate(forAmount: .greaterThan(100))).thenReturn("high") // 200
    when(mock.rate(forAmount: 500)).thenReturn("exact")              // 500

    // 500 matches all three stubs; the highest precedence wins.
    #expect(service.rate(forAmount: 500) == "exact")

    // 250 matches .greaterThan and .any; 200 beats 0.
    #expect(service.rate(forAmount: 250) == "high")

    // 5 matches only .any.
    #expect(service.rate(forAmount: 5) == "any")
}
