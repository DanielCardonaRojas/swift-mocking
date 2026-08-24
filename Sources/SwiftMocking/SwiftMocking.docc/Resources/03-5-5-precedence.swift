import SwiftMocking
import Testing

@Test
func precedenceIsSummedAcrossArguments() {
    let mock = MockRateService()
    let service: any RateService = mock

    // Two predicates: 200 + 200 = 400
    when(mock.fee(amount: .greaterThan(0), currency: .any(that: { !$0.isEmpty })))
        .thenReturn("both predicates")

    // One exact value and one .any: 500 + 0 = 500
    when(mock.fee(amount: 100, currency: .any))
        .thenReturn("one exact")

    // Both stubs match this call, but 500 > 400 — so specificity is a
    // property of the whole call, not of any single argument.
    #expect(service.fee(amount: 100, currency: "USD") == "one exact")
}
