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
/// Thread safety comes from holding the dictionary in a ``LockIsolated`` box.
public final class SpyStorageProvider: Sendable {
    public typealias Storage = [String: [String: [AnySpy]]]

    private let _storage: LockIsolated<Storage>

    /// Thread-safe access to the underlying storage.
    ///
    /// Each individual get or set is synchronized, but a sequence of them is not. Use
    /// ``withStorage(_:)`` for any read-modify-write.
    public var storage: Storage {
        get { _storage.withLock { $0 } }
        set { _storage.withLock { $0 = newValue } }
    }

    /// Performs a read-modify-write against the storage under a single lock acquisition.
    ///
    /// - Parameter body: A closure receiving the storage `inout`.
    /// - Returns: Whatever `body` returns.
    public func withStorage<R>(_ body: (inout Storage) throws -> R) rethrows -> R {
        try _storage.withLock(body)
    }

    /// Creates a storage provider with an optional pre-populated dictionary.
    /// - Parameter storage: Existing spy storage. Defaults to an empty dictionary.
    public init(storage: Storage = [:]) {
        self._storage = LockIsolated(storage)
    }
}

