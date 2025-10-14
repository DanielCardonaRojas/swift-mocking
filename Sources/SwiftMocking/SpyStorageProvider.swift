//
//  SpyStorageProvider.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 27/01/25.
//

/// Lightweight storage container for static mock spies.
///
/// The provider owns the raw dictionary that mirrors the storage layout used by `Mock`.
/// It can be shared across different execution contexts to coordinate spy access.
final class SpyStorageProvider {
    typealias Storage = [String: [String: [AnySpy]]]

    var storage: Storage

    /// Creates a storage provider with an optional pre-populated dictionary.
    /// - Parameter storage: Existing spy storage. Defaults to an empty dictionary.
    init(storage: Storage = [:]) {
        self.storage = storage
    }
}

