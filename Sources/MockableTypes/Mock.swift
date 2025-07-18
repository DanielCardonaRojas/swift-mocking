//
//  Mock.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 13/07/25.
//

/// A base class for creating mock objects that automatically generates and manages spies for its methods.
///
/// The `Mock` class uses `@dynamicMemberLookup` to dynamically create and return ``Spy`` instances
/// for any member accessed on the mock object. This allows you to write tests for protocol interactions
/// without having to manually create spy properties for each method in your mock implementation.
///
/// Each spy is stored internally and reused on subsequent accesses, ensuring that all interactions
/// for a specific method are recorded in the same spy instance.
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

    public var defaultProviderRegistry: DefaultProvidableRegistry = .shared

    /// Stores spies per protocol  requirement. Keys are function or variable names.
    private(set) var spies: [String: AnySpy] = [:]

    /// Stores spies per protocol requirement. Keys in the outermost dictionary correspond to the Mock type,
    /// keys in the inner dictionary are function or variable names. This enables tracking spies for static requirements.
    static private var spies_: [String: [String: AnySpy]] = [:]

    public var isLoggingEnabled: Bool = false {
        didSet {
            spies.values.forEach({ $0.isLoggingEnabled = isLoggingEnabled })
        }
    }

    public static var isLoggingEnabled: Bool = false {
        didSet {
            for dict in spies_.values {
                dict.values.forEach({ $0.isLoggingEnabled = isLoggingEnabled })
            }
        }
    }

    public init() { }

    static var spies: [String: AnySpy] {
        spies_["\(Self.self)"] ?? [:]
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
        if let existingSpy = spies[member] as? Spy<repeat each Input, Eff, Output> {
            return existingSpy
        } else {
            let spy = Spy<repeat each Input, Eff, Output>()
            spy.configureLogger(label: "\(Self.self).\(member)")
            spy.isLoggingEnabled = isLoggingEnabled
            spies[member] = spy
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
        let thisType = "\(Self.self)" // The name of the subclass mock
        if spies_[thisType] == nil {
            spies_[thisType] = [:]
        }

        if let existingSpy = spies_[thisType]?[member] as? Spy<repeat each Input, Eff, Output> {
            return existingSpy
        } else {
            let spy = Spy<repeat each Input, Eff, Output>()
            spy.configureLogger(label: "\(Self.self).\(member)")
            spy.isLoggingEnabled = isLoggingEnabled
            spies_[thisType]?[member] = spy
            return spy
        }
    }

    /// Clears all recorded invocations and stubs from all spies managed by this mock.
    ///
    /// Call this method in your test's `tearDown` to ensure that each test starts with a
    /// clean mock object, free from any interactions or stubs from previous tests.
    public func clear() {
        spies.values.forEach { $0.clear() }
    }
}

