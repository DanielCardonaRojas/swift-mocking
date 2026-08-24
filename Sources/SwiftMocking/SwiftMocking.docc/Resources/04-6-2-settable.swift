func testReadsAndWritesAreCountedSeparately() {
    let mock = MockFeatureFlags()
    when(mock.isEnabled).thenReturn(true)

    _ = mock.isEnabled       // a read
    mock.isEnabled = false   // a write

    // Reads and writes live on separate spies.
    verify(mock.isEnabled).called(1)           // counts reads only
    verify(mock.isEnabled <- false).called(1)  // counts writes only
}
