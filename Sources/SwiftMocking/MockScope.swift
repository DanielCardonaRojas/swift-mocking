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
public enum MockScope {
    @TaskLocal
    static var storageProvider: SpyStorageProvider = SpyStorageProvider()

    /// Task-local registry for default values used by spy instances.
    ///
    /// This registry is used by spy instances to provide default values for unstubbed method calls.
    /// It can be overridden within a task scope using `withDefaults(_:body:)` to provide
    /// test-specific default values.
    @TaskLocal
    static var fallbackValueRegistry: DefaultProvidableRegistry = .default

    /// Task-local invocation recorder for cross-spy verification.
    ///
    /// This recorder maintains a chronological timeline of all method calls for cross-spy
    /// verification. Each task can have its own isolated recorder for test isolation.
    @TaskLocal
    public static var invocationRecorder: InvocationRecorder = .shared

    /// Returns the storage provider bound to the current task.
    public static var currentStorage: SpyStorageProvider {
        storageProvider
    }

    /// Executes a synchronous closure with the given provider and a fresh invocation recorder.
    /// - Parameters:
    ///   - provider: Storage provider used within the body.
    ///   - body: Synchronous closure to run with the provider.
    /// - Returns: The value returned by the closure.
    public static func withStorage<R>(
        _ provider: SpyStorageProvider = .init(),
        body: () throws -> R
    ) rethrows -> R {
        try $storageProvider.withValue(provider) {
            try $invocationRecorder.withValue(InvocationRecorder(), operation: body)
        }
    }

    /// Executes an asynchronous closure with the given provider and a fresh invocation recorder.
    /// - Parameters:
    ///   - provider: Storage provider used within the body.
    ///   - body: Asynchronous closure to run with the provider.
    /// - Returns: The value returned by the closure.
    static func withStorage<R>(
        _ provider: SpyStorageProvider = .init(),
        body: () async throws -> R
    ) async rethrows -> R {
        try await $storageProvider.withValue(provider) {
            try await $invocationRecorder.withValue(InvocationRecorder(), operation: body)
        }
    }

    /// Executes an asynchronous closure with a custom default value registry.
    ///
    /// This method establishes a task-local scope where all spy instances created within
    /// the closure will use the specified default value registry instead of the global one.
    /// This is primarily used internally by `DefaultValuesTrait` to provide test-scoped
    /// default values.
    ///
    /// - Parameters:
    ///   - provider: The default value registry to use within the scope. Defaults to the
    ///     global default registry.
    ///   - body: The asynchronous closure to execute with the custom registry.
    ///
    /// - Returns: The value returned by the closure.
    ///
    /// - Throws: Any error thrown by the closure.
    static func withDefaults<R>(
        _ provider: DefaultProvidableRegistry = .default,
        body: () async throws -> R
    ) async rethrows -> R {
        try await $fallbackValueRegistry.withValue(provider, operation: body)
    }

    /// Clears all spy storage and the current task's invocation recorder.
    ///
    /// This function clears the spy storage for static mocks and the invocation recorder
    /// for the current task. Note that with task-local recorders, each test typically
    /// gets its own isolated recorder automatically via `withStorage` or `MockingTestCase`.
    public static func clearAll() {
        storageProvider.storage.removeAll()
        Task {
            await invocationRecorder.clear()
        }
    }

    /// Executes a closure with a clean mock environment.
    ///
    /// This method automatically provides fresh spy storage and invocation recorder
    /// for the provided closure, ensuring test isolation.
    ///
    /// - Parameter body: Closure to execute with clean mock state
    /// - Returns: The value returned by the closure
    public static func withCleanEnvironment<R>(
        body: () async throws -> R
    ) async rethrows -> R {
        try await withStorage(SpyStorageProvider()) {
            try await body()
        }
    }
}

