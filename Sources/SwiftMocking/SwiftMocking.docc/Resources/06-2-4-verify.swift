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

    let client = FeatureFlagClient(
        isEnabled: adapt(isEnabledSpy),
        refresh: adapt(refreshSpy),
        record: adapt(recordSpy)
    )

    let model = await RolloutModel(client: client)
    try await model.onAppear()

    #expect(await model.banner == "New checkout")
    verify(refreshSpy(.any)).called(1)
    verify(isEnabledSpy(.equal("checkout-v2"))).called(1)
    verify(recordSpy("checkout-v2", 1)).called(1)
}
