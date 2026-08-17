func testSideEffects() {
    let mock = MockSyncEngine()
    var refreshed: [String] = []

    // Observe every call with .do...
    when(mock.refresh(id: .any)).do { id in
        refreshed.append(id)
    }
    // ...and stub the same matcher so the call resolves cleanly.
    when(mock.refresh(id: .any)).thenReturn(())

    mock.refresh(id: "primary")
    mock.refresh(id: "backup")

    XCTAssertEqual(refreshed, ["primary", "backup"])
    verify(mock.refresh(id: .any)).called(2)
}
