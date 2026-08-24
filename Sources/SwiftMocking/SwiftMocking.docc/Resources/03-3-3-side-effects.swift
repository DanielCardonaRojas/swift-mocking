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
}
