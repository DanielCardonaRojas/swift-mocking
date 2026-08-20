import Foundation

/// A thread-safe collector for values observed inside a stub's handler closure.
///
/// Stub handlers are `@Sendable`, so a test cannot append to a local `var` from
/// inside one. ``CaptureBox`` gives that recording a home whose mutation is
/// lock-guarded, letting a test assert on what a stub actually received:
///
/// ```swift
/// let written = CaptureBox<Int>()
/// when(mock.value <- 7).thenReturn { _, newValue in
///     written.append(newValue)
/// }
/// mock.value = 7
/// XCTAssertEqual(written.values, [7])
/// ```
///
/// Prefer `verify(...).captured { ... }` when the assertion is about recorded
/// invocations; reach for a `CaptureBox` when what matters is that a *stub
/// handler ran* — with the values it was handed, in order.
public final class CaptureBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Value] = []

    /// Creates an empty box.
    public init() {}

    /// Appends a value observed inside a handler closure.
    public func append(_ value: Value) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(value)
    }

    /// The values appended so far, in order.
    public var values: [Value] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
