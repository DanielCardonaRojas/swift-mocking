import Foundation

// Stub handlers are @Sendable, so record into a small thread-safe box.
final class IntRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Int] = []

    var values: [Int] { lock.withLock { storage } }

    func append(_ value: Int) {
        lock.withLock { storage.append(value) }
    }
}

@Test
@Test
func observeWritesAsTheyHappen() {
    let mock = MockFeatureFlags()

    let written = IntRecorder()
    when(mock.retryCount <- .any).thenReturn { _, newValue in
        written.append(newValue)
    }

    mock.retryCount = 1
    mock.retryCount = 2

    #expect(written.values == [1, 2])

    // A write interaction is an ordinary Interaction, so it composes
    // with verifyInOrder. A *read* needs its explicit `.get` form,
    // since SettableInteraction itself isn't CrossSpyVerifiable.
    verifyInOrder([mock.retryCount <- 1, mock.retryCount <- 2])
}
