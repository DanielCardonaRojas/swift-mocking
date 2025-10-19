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
open class Mock: DefaultProvider {
    /// This provides a way to access super as if it where in a static context.
    ///
    ///  `super.myProtocolFunc` will use the instance subscript to create/read a spy when it is used in a non static context.
    ///   when it is used in a static context it will use a the static subscript. This provide a mechanism to select static super.
    public var Super: Mock.Type {
        Self.self as Mock.Type
    }

    public var defaultProviderRegistry: DefaultProvidableRegistry = MockScope.fallbackValueRegistry
    public static var defaultProviderRegistry: DefaultProvidableRegistry = MockScope.fallbackValueRegistry

    /// Stores spies per protocol  requirement. Keys are function or variable names.
    private(set) var spies: [String: [AnySpy]] = [:]

    private static let lock = NSLock()
    private let lock = NSLock()

    public var isLoggingEnabled: Bool = false {
        didSet {
            for spyGroup in spies.values {
                spyGroup.forEach({ $0.isLoggingEnabled = isLoggingEnabled})
            }
        }
    }

    public static var isLoggingEnabled: Bool = false {
        didSet {
            let provider = MockScope.storageProvider
            for dict in provider.storage.values {
                for spyGroup in dict.values {
                    spyGroup.forEach({ $0.isLoggingEnabled = isLoggingEnabled })
                }
            }
        }
    }

    public init() { }

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
        if let existingSpy = spies[member]?.firstMap({ $0 as? Spy<repeat each Input, Eff, Output> })  {
            return existingSpy
        } else {
            let spy = Spy<repeat each Input, Eff, Output>()
            spy.configureLogger(label: "\(Self.self).\(member)")
            spy.isLoggingEnabled = isLoggingEnabled
            spy.defaultProviderRegistry = defaultProviderRegistry
            spies[member, default: []].append(spy)
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
            let spy = Spy<repeat each Input, Eff, Output>()
            spy.configureLogger(label: "\(Self.self).\(member)")
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
        for spyGroup in spies.values {
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
