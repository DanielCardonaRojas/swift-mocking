//
//  DefaultValuesTrait.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 18/10/25.
//

import Testing

/// A test trait that provides test-scoped default values for unstubbed mock methods.
///
/// This trait allows you to inject specific default values that will be returned by unstubbed mocks
/// within the scope of a test. Unlike the global `DefaultProvidableRegistry.shared`, values registered
/// through this trait are isolated to the test execution scope.
///
/// Usage:
/// ```swift
/// @Test(.withDefaults(
///     User(id: "test-user", name: "Test User"),
///     42,
///     "Hello World"
/// ))
/// func testWithCustomDefaults() {
///     let mock = MockUserService()
///     // If fetchUser() is not stubbed, it will return User(id: "test-user", name: "Test User")
///     let user = mock.fetchUser()
///     #expect(user.name == "Test User")
/// }
/// ```
public struct DefaultValuesTrait: TestTrait, SuiteTrait, TestScoping {
    private var registry: DefaultProvidableRegistry

    public init(_ values: [DefaultProviding]) {
        registry = .default
        values.forEach {
            registry.register($0)
        }
    }

    public func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        try await MockScope.withDefaults(registry) {
            try await function()
        }
    }
}

public extension Trait where Self == DefaultValuesTrait {
    /// Creates a trait that provides test-scoped default values for unstubbed mock methods.
    ///
    /// - Parameter values: The default values to be used for unstubbed mock methods of matching types.
    /// - Returns: A `DefaultValuesTrait` configured with the provided values.
    static func withDefaults<each Value>(_ values: repeat each Value) -> DefaultValuesTrait {
        var providers = [DefaultProviding]()

        for value in repeat each values {
            providers.append(DefaultProviding.valueProvider(value))
        }

        return DefaultValuesTrait(providers)
    }
}
