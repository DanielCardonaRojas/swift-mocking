func testSideEffects() {
    let mock = MockSyncEngine()
    var refreshed: [String] = []

    // Observe every call with .do...
    when(mock.refresh(id: .any)).do { id in
        refreshed.append(id)
    }
