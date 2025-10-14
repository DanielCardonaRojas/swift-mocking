//
//  MockScope.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 27/01/25.
//

import Foundation

/// Provides scoped access to the shared spy storage used by static mock requirements.
///
/// Swift Testing can run tests concurrently. When mocking static protocol requirements each test
/// should see its own set of spies. ``MockScope`` exposes a ``TaskLocal`` value that allows tests
/// to install a custom ``SpyStorageProvider`` for the duration of a scope.
///
/// ```swift
/// try await MockScope.withStorage(SpyStorageProvider()) {
///     // Interact with mocks. Static requirements stay isolated to this scope.
/// }
/// ```
enum MockScope {
    @TaskLocal
    static var storageProvider: SpyStorageProvider = SpyStorageProvider()

    /// Returns the storage provider bound to the current task.
    static var currentStorage: SpyStorageProvider {
        storageProvider
    }

    /// Executes a synchronous closure with the given provider.
    /// - Parameters:
    ///   - provider: Storage provider used within the body.
    ///   - body: Synchronous closure to run with the provider.
    /// - Returns: The value returned by the closure.
    static func withStorage<R>(
        _ provider: SpyStorageProvider,
        body: () throws -> R
    ) rethrows -> R {
        try $storageProvider.withValue(provider, operation: body)
    }

    /// Executes an asynchronous closure with the given provider.
    /// - Parameters:
    ///   - provider: Storage provider used within the body.
    ///   - body: Asynchronous closure to run with the provider.
    /// - Returns: The value returned by the closure.
    static func withStorage<R>(
        _ provider: SpyStorageProvider,
        body: () async throws -> R
    ) async rethrows -> R {
        try await $storageProvider.withValue(provider, operation: body)
    }
}

