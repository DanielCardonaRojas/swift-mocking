func testNotificationArrivesEventually() async throws {
    let mock = MockSyncEngine()
    when(mock.refresh(id: .any)).thenReturn(())

    // Work that finishes on some other task, at some unknown time.
    Task {
        try? await Task.sleep(for: .milliseconds(20))
        mock.refresh(id: "late")
    }

    // Suspend until a matching call is recorded, or fail after the timeout.
    try await until(mock.refresh(id: .any), timeout: .seconds(2))

    verify(mock.refresh(id: "late")).called()
}
