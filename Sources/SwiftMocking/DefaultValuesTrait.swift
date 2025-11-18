//
//  DefaultValuesTrait.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 18/10/25.
//

import Testing

#if swift(>=6.1)
/// A test trait that provides test-scoped default values for unstubbed mock methods.
///
/// This trait allows you to inject specific default values that will be returned by unstubbed mocks
/// within the scope of a test execution. Unlike the global `DefaultProvidableRegistry.default`, values
/// registered through this trait are isolated to the test execution scope and don't affect other tests.
///
public struct DefaultValuesTrait: TestTrait, SuiteTrait, TestScoping {
    /// The registry containing the custom default value providers for this trait.
    private var registry: DefaultProvidableRegistry

    /// Creates a new `DefaultValuesTrait` with the specified default value providers.
    ///
    /// - Parameter values: An array of `DefaultProviding` instances that will supply
    ///   default values for their respective types.
    public init(_ values: [DefaultProviding]) {
        registry = .default
        values.forEach {
            registry.register($0)
        }
    }

    /// Provides a test execution scope with custom default values.
    ///
    /// This method is called by the Swift Testing framework to establish the test scope.
    /// It sets up a task-local registry containing the custom default values and executes
    /// the test function within that scope.
    ///
    /// - Parameters:
    ///   - test: The test being executed.
    ///   - testCase: The specific test case, if applicable.
    ///   - function: The test function to execute within the scoped environment.
    ///
    /// - Throws: Any error thrown by the test function.
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
    /// This method allows you to specify concrete values that will be used as defaults for
    /// unstubbed mock methods during test execution.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Suite(.withDefaults("Default Name"))
    /// struct UserServiceTests {
    ///     @Test
    ///     func testBasicUser() {
    ///         let mock = MockUserService()
    ///         let name = mock.getUserName() // Returns "Default Name"
    ///     }
    ///
    ///     @Test(.withDefaults("Override Name"))
    ///     func testSpecialUser() {
    ///         let mock = MockUserService()
    ///         let name = mock.getUserName() // Returns "Override Name"
    ///     }
    /// }
    /// ```
    static func withDefaults<each Value: Sendable>(_ values: repeat each Value) -> DefaultValuesTrait {
        var providers = [DefaultProviding]()

        for value in repeat each values {
            providers.append(DefaultProviding.valueProvider(value))
        }

        return DefaultValuesTrait(providers)
    }
}
#endif
