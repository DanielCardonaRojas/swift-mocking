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
}
