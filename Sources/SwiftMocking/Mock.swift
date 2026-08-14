//
//  Mock.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 13/07/25.
//
import Foundation

/// A base class for creating mock objects that automatically generates and manages spies for its methods.
///
/// The `Mock` class uses `@dynamicMemberLookup` to dynamically create and return ``Spy`` instances
/// for any member accessed on the mock object. This allows you to write tests for protocol interactions
/// without having to manually create spy properties for each method in your mock implementation.
///
/// Each spy is stored internally and reused on subsequent accesses, ensuring that all interactions
/// for a specific method are recorded in the same spy instance.
///
/// Mock classes are typically generated using the ``Mockable`` macro rather than created manually.
/// The generated mocks inherit from this base class and provide protocol-specific implementations.
///
/// ## Related Types
/// - ``Spy`` - Records method invocations and manages stubs
/// - ``Interaction`` - Represents a method call for stubbing and verification
/// - ``ArgMatcher`` - Matches method arguments with various criteria
///
@dynamicMemberLookup
open class Mock: DefaultProvider, @unchecked Sendable {
    /// This provides a way to access super as if it where in a static context.
    ///
    ///  `super.myProtocolFunc` will use the instance subscript to create/read a spy when it is used in a non static context.
    ///   when it is used in a static context it will use a the static subscript. This provide a mechanism to select static super.
    public var Super: Mock.Type {
        Self.self as Mock.Type
    }

    /// Guards post-init instance configuration (`defaultProviderRegistry`,
    /// `isLoggingEnabled`) so the @unchecked Sendable conformance is honest.
    private let configLock = NSLock()

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        configLock.lock()
        defer { configLock.unlock() }
        return try body()
    }

    private var _defaultProviderRegistry: DefaultProvidableRegistry = MockScope.fallbackValueRegistry
    public var defaultProviderRegistry: DefaultProvidableRegistry {
        get { locked { _defaultProviderRegistry } }
        set {
            locked { _defaultProviderRegistry = newValue }
            for spyGroup in snapshotSpies().values {
                spyGroup.forEach { $0.defaultProviderRegistry = newValue }
            }
        }
    }
    public static var defaultProviderRegistry: DefaultProvidableRegistry {
        MockScope.fallbackValueRegistry
    }

    /// Stores spies per protocol  requirement. Keys are function or variable names.
    private var _spies: [String: [AnySpy]] = [:]
    /// A point-in-time snapshot of the spies managed by this mock.
    var spies: [String: [AnySpy]] { snapshotSpies() }

    private static let lock = NSLock()
    private let lock = NSLock()

    private var _isLoggingEnabled = false
    public var isLoggingEnabled: Bool {
        get { locked { _isLoggingEnabled } }
        set {
            locked { _isLoggingEnabled = newValue }
            for spyGroup in snapshotSpies().values {
                spyGroup.forEach { $0.isLoggingEnabled = newValue }
            }
        }
    }

    // NOTE: Using nonisolated(unsafe) here because Swift 6 strict concurrency
    // does not allow static mutable properties without proper isolation.
    // The actual thread safety is provided by the NSLock-based synchronization
    // in the computed property below. This is a known limitation and a
    // future improvement would be to use an actor for this state.
    private static let loggingLock = NSLock()
    private nonisolated(unsafe) static var _isLoggingEnabled: Bool = false

    /// Thread-safe access to static logging enabled state.
    ///
    /// Uses NSLock-based synchronization to prevent data races when
    /// multiple threads access or modify the logging state concurrently.
    public static var isLoggingEnabled: Bool {
        get {
            loggingLock.lock()
            defer { loggingLock.unlock() }
            return _isLoggingEnabled
        }
        set {
            loggingLock.lock()
            defer { loggingLock.unlock() }
            _isLoggingEnabled = newValue
            // Propagate to existing spies
            let provider = MockScope.storageProvider
            for dict in provider.storage.values {
                for spyGroup in dict.values {
                    spyGroup.forEach({ $0.isLoggingEnabled = newValue })
                }
            }
        }
    }

    public init() { }

    /// Returns a deep, point-in-time copy of the instance spy storage.
    ///
    /// The copy is taken under `lock` and fully disconnects its storage from `spies`
    /// (a fresh dictionary of fresh arrays) so callers can iterate it outside the lock
    /// without racing the locked writes in `subscript(dynamicMember:)` — including the
    /// dictionary resize those writes trigger, which operates on shared CoW storage if a
    /// shallow copy escapes the lock.
    private func snapshotSpies() -> [String: [AnySpy]] {
        lock.lock()
        defer { lock.unlock() }
        return _spies.mapValues { Array($0) }
    }

    static var spies: [String: [AnySpy]] {
        let provider = MockScope.storageProvider
        return provider.storage["\(Self.self)"] ?? [:]
    }

    /// Provides a ``Spy`` instance for the given member name.
    ///
    /// This subscript is the core of the `@dynamicMemberLookup` functionality. When you access a
    /// member on a `Mock` instance (e.g., `mock.myMethod`), this subscript is called with the
    /// member's name as a string. It then either returns an existing spy for that name or
    /// creates a new one, stores it, and returns it.
    ///
    /// - Parameter member: The name of the member being accessed.
    /// - Returns: A ``Spy`` instance configured for the member's signature.
    public subscript<each Input, Eff: Effect, Output>(dynamicMember member: String) -> Spy<repeat each Input, Eff, Output> {
        lock.lock()
        defer { lock.unlock() }
        if let existingSpy = _spies[member]?.firstMap({ $0 as? Spy<repeat each Input, Eff, Output> })  {
            return existingSpy
        } else {
            let methodLabel = "\(Self.self).\(member)"
            let spy = Spy<repeat each Input, Eff, Output>(label: methodLabel)
            spy.isLoggingEnabled = isLoggingEnabled
            spy.defaultProviderRegistry = defaultProviderRegistry
            _spies[member, default: []].append(spy)
            return spy
        }
    }

    /// Provides a ``Spy`` instance for the given member name.
    ///
    /// This subscript is the core of the `@dynamicMemberLookup` functionality. When you access a
    /// member on a `Mock` static type (e.g., `MyMock.myMethod`), this subscript is called with the
    /// member's name as a string. It then either returns an existing spy for that name or
    /// creates a new one, stores it, and returns it.
    ///
    /// - Parameter member: The name of the member being accessed.
    /// - Returns: A ``Spy`` instance configured for the member's signature.
    public static subscript<each Input, Eff: Effect, Output>(dynamicMember member: String) -> Spy<repeat each Input, Eff, Output> {
        lock.lock()
        defer { lock.unlock() }
        let provider = MockScope.storageProvider
        let thisType = "\(Self.self)" // The name of the subclass mock
        var storage = provider.storage[thisType] ?? [:]

        if let spyGroup = storage[member], let existingSpy = spyGroup.firstMap({ $0 as? Spy<repeat each Input, Eff, Output> }) {
            return existingSpy
        } else {
            let methodLabel = "\(Self.self).\(member)"
            let spy = Spy<repeat each Input, Eff, Output>(label: methodLabel)
            spy.isLoggingEnabled = isLoggingEnabled
            spy.defaultProviderRegistry = defaultProviderRegistry
            storage[member, default: []].append(spy)
            provider.storage[thisType] = storage
            return spy
        }
    }

    /// Clears all recorded invocations and stubs from all spies managed by this mock.
    ///
    /// Call this method in your test's `tearDown` to ensure that each test starts with a
    /// clean mock object, free from any interactions or stubs from previous tests.
    public func clear() {
        for spyGroup in snapshotSpies().values {
            spyGroup.forEach { $0.clear() }
        }
    }

    /// Clears all recorded invocations and stubs from all spies managed by this static instance.
    ///
    /// Call this method in your test's `tearDown` to ensure that each test starts with a
    /// clean mock object, free from any interactions or stubs from previous tests.
    public static func clear() {
        let provider = MockScope.storageProvider
        for dict in provider.storage.values {
            for spyGroup in dict.values {
                spyGroup.forEach({ $0.clear() })
            }
        }
    }
}
