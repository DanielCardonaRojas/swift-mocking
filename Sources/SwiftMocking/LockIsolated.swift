//
//  LockIsolated.swift
//  swift-mocking
//

import Foundation

/// A mutable value whose every access is serialized by a lock.
///
/// A type holding all of its mutable state in `LockIsolated` properties can conform to
/// `Sendable` directly, rather than asserting it with `@unchecked`:
///
/// ```swift
/// final class Counter: Sendable {
///     private let count = LockIsolated(0)
///     func increment() { count.withLock { $0 += 1 } }
///     var value: Int { count.withLock { $0 } }
/// }
/// ```
///
/// Stands in for `Synchronization.Mutex`, which requires macOS 15 / iOS 18 — above this
/// package's deployment floor. `withLock` mirrors its shape, so callers need not change
/// if the floor rises.
///
/// - Important: Do not escape the `inout` value from `withLock`, and prefer not to call
///   user-supplied code inside it — the lock is not recursive, so re-entering
///   `withLock` on the same instance deadlocks.
public final class LockIsolated<Value: Sendable>: Sendable {
    /// Every access goes through `withLock`, which holds `lock` for the duration.
    private nonisolated(unsafe) var _value: Value
    private let lock = NSLock()

    /// Creates a box holding `value`.
    public init(_ value: Value) {
        self._value = value
    }

    /// Runs `body` with exclusive access to the boxed value.
    ///
    /// - Parameter body: A closure receiving the value `inout`.
    /// - Returns: Whatever `body` returns.
    public func withLock<R>(_ body: (inout Value) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try body(&_value)
    }
}
