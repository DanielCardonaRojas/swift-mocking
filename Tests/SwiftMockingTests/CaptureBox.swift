import Foundation
@testable import SwiftMocking

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
///
/// Conditionally `Sendable`: a box crosses isolation domains only when the values it
/// collects can. Unconstrained otherwise, so a test can still gather non-`Sendable`
/// values on a single domain.
final class CaptureBox<Value> {
    private let storage = UncheckedLockIsolated<[Value]>([])

    /// Creates an empty box.
    init() {}

    /// Appends a value observed inside a handler closure.
    func append(_ value: Value) {
        storage.withLock { $0.append(value) }
    }

    /// The values appended so far, in order.
    var values: [Value] {
        storage.withLock { $0 }
    }
}

extension CaptureBox: Sendable where Value: Sendable { }
