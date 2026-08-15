//
//  SpyStorageProvider.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 27/01/25.
//

import Foundation

/// Lightweight storage container for static mock spies.
///
/// The provider owns the raw dictionary that mirrors the storage layout used by `Mock`.
/// It can be shared across different execution contexts to coordinate spy access.
///
/// Thread safety is ensured through NSLock-based synchronization, justifying
/// the `@unchecked Sendable` conformance.
public final class SpyStorageProvider: @unchecked Sendable {
    public typealias Storage = [String: [String: [AnySpy]]]

    private let lock = NSLock()
    private var _storage: Storage

    /// Thread-safe access to the underlying storage.
    ///
    /// All accesses are synchronized through an internal lock to prevent
    /// data races when multiple threads read or modify the storage concurrently.
    public var storage: Storage {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _storage
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _storage = newValue
        }
    }

    /// Creates a storage provider with an optional pre-populated dictionary.
    /// - Parameter storage: Existing spy storage. Defaults to an empty dictionary.
    public init(storage: Storage = [:]) {
        self._storage = storage
    }
}

