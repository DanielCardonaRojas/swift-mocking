import SwiftMocking
import Testing

@Test
func registrationOrderDoesNotMatter() {
    let mock = MockRateService()
    let service: any RateService = mock

    // The exact same three stubs, now registered in the opposite
    // order — most specific first, broadest last.
    when(mock.rate(forAmount: 500)).thenReturn("exact")
    when(mock.rate(forAmount: .greaterThan(100))).thenReturn("high")
    when(mock.rate(forAmount: .any)).thenReturn("any")

    // Identical results. A late `.any` does not override an earlier
    // `.equal`: 500 still outranks 0.
    #expect(service.rate(forAmount: 500) == "exact")
    #expect(service.rate(forAmount: 250) == "high")
    #expect(service.rate(forAmount: 5) == "any")
}
