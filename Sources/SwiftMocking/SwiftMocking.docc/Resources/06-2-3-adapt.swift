import Testing
import SwiftMocking

@Test
func showsNewCheckoutBanner() async throws {
    let isEnabledSpy = Spy<String, None, Bool>()
    let refreshSpy = Spy<Void, AsyncThrows, Void>()
    let recordSpy = Spy<String, Int, Throws, Void>()

    when(isEnabledSpy(.equal("checkout-v2"))).thenReturn(true)
    when(isEnabledSpy(.any)).thenReturn(false)
    when(refreshSpy(.any)).thenReturn(())
    when(recordSpy(.any, .any)).thenReturn(())

    // `adapt` turns each spy into the @Sendable function value the struct wants.
    let client = FeatureFlagClient(
        isEnabled: adapt(isEnabledSpy),
        refresh: adapt(refreshSpy),
        record: adapt(recordSpy)
    )
}
