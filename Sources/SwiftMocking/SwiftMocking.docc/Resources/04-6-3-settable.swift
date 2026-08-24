@Test
func readsAndWritesAreCountedSeparately() {
    let mock = MockFeatureFlags()
    when(mock.isEnabled).thenReturn(true)

    _ = mock.isEnabled       // a read
    mock.isEnabled = false   // a write

    // Reads and writes live on separate spies.
    verify(mock.isEnabled).called(1)           // counts reads only
    verify(mock.isEnabled <- false).called(1)  // counts writes only

    // Matchers work on the written value, and `captured` receives
    // the read pack first, the written value last.
    mock.retryCount = 3
    mock.retryCount = 9

    verify(mock.retryCount <- .greaterThan(5)).called(1)
    verify(mock.retryCount <- .any).called(2)
    verify(mock.retryCount <- .any).captured { _, newValue in
        #expect(newValue == 3 || newValue == 9)
    }

    // Never written at all?
    verifyNever(mock.isEnabled <- .equal(true))
}
