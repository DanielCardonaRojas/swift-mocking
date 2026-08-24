import SwiftMocking
import Testing

@Test
func recencyBreaksTiesAtEqualPrecedence() {
    let mock = MockRateService()
    let service: any RateService = mock

    // Same matcher twice, so the totals tie at 0.
    when(mock.rate(forAmount: .any)).thenReturn("first")
    when(mock.rate(forAmount: .any)).thenReturn("second")

    // Only when precedence ties does registration order decide.
    #expect(service.rate(forAmount: 1) == "second")
}
