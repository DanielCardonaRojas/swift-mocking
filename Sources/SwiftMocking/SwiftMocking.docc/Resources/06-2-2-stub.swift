import Testing
import SwiftMocking

@Test
func showsNewCheckoutBanner() async throws {
    let isEnabledSpy = Spy<String, None, Bool>()
    let refreshSpy = Spy<Void, AsyncThrows, Void>()
    let recordSpy = Spy<String, Int, Throws, Void>()

    // The same `when` vocabulary as a generated mock — matchers and all.
    when(isEnabledSpy(.equal("checkout-v2"))).thenReturn(true)
    when(isEnabledSpy(.any)).thenReturn(false)
    when(refreshSpy(.any)).thenReturn(())
    when(recordSpy(.any, .any)).thenReturn(())
}
