@Test
func composedStructRecordsCalls() {
    let analytics = StructAnalytics()

    // Reads exactly like a generated mock.
    when(analytics.track(.any)).thenReturn(())
    analytics.track("opened")
    verify(analytics.track(.equal("opened"))).called(1)

    // clear() comes free from MockProviding.
    analytics.clear()
    verify(analytics.track(.any)).neverCalled()
}
