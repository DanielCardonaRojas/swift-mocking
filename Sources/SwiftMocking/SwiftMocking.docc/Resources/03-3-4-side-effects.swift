import Foundation

// `.do` handlers are @Sendable, so record into a small thread-safe
// box rather than capturing a mutable `var`.
final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var values: [String] { lock.withLock { storage } }

    func append(_ value: String) {
        lock.withLock { storage.append(value) }
    }
}

func testSideEffects() {
    let mock = MockSyncEngine()
    let refreshed = Recorder()

    // Observe every call with .do...
    when(mock.refresh(id: .any)).do { id in
        refreshed.append(id)
    }
    // ...and stub the same matcher so the call resolves cleanly.
    when(mock.refresh(id: .any)).thenReturn(())

    mock.refresh(id: "primary")
    mock.refresh(id: "backup")

    XCTAssertEqual(refreshed.values, ["primary", "backup"])
    verify(mock.refresh(id: .any)).called(2)
}
