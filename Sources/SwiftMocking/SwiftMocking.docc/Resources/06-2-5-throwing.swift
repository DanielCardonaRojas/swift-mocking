@Test
func surfacesRefreshFailure() async throws {
    struct Boom: Error {}

    let refreshSpy = Spy<Void, AsyncThrows, Void>()
    when(refreshSpy(.any)).thenThrow(Boom())

    // Only the closure under test needs a spy; the rest can be plain stubs.
    let client = FeatureFlagClient(
        isEnabled: { _ in false },
        refresh: adapt(refreshSpy),
        record: { _, _ in }
    )

    await #expect(throws: Boom.self) {
        try await client.refresh()
    }
}
