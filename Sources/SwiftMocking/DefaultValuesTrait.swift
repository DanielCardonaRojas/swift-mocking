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
/// within the scope of a test execution. Unlike the global `DefaultProvidableRegistry.default`, values
/// registered through this trait are isolated to the test execution scope and don't affect other tests.
///
/// ## Overview
///
/// When a mock method is called but hasn't been explicitly stubbed, SwiftMocking normally returns
/// a default value (like empty string for `String`, `0` for `Int`, etc.). The `DefaultValuesTrait`
/// allows you to override these defaults with specific values for the duration of a test.
///
/// ## Usage
///
/// ### Test-Level Defaults
///
/// Apply custom defaults to individual tests:
///
/// ```swift
/// @Test(.withDefaults("Test User", 42, true))
/// func testUserCreation() {
///     let mock = MockUserService()
///
///     // These return the custom defaults instead of global ones
///     let name = mock.getUserName()     // Returns "Test User"
///     let age = mock.getUserAge()       // Returns 42
///     let active = mock.isUserActive()  // Returns true
/// }
/// ```
///
/// ### Suite-Level Defaults
///
/// Apply defaults to an entire test suite:
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
///
/// ## Type Matching
///
/// The trait matches types exactly - if you provide a `String` value, it will be used as the default
/// for any unstubbed method that returns `String`. Complex types work the same way:
///
/// ```swift
/// struct User { let name: String, age: Int }
///
/// @Test(.withDefaults(User(name: "Test", age: 25)))
/// func testUserService() {
///     let mock = MockUserService()
///     let user = mock.createUser() // Returns User(name: "Test", age: 25)
/// }
/// ```
///
/// ## Composition
///
/// This trait composes well with other traits:
///
/// ```swift
/// @Test(.mocking, .withDefaults("Isolated User"))
/// func testWithIsolation() {
///     // Both test isolation and custom defaults are active
/// }
/// ```
///
/// - Note: When both suite-level and test-level defaults are specified for the same type,
///   the test-level default takes precedence.
/// - Important: This trait only affects unstubbed method calls. Explicitly stubbed methods
///   always return their stubbed values regardless of any defaults specified here.
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
    /// unstubbed mock methods during test execution. The values are matched by type - any
    /// unstubbed method returning the same type as one of the provided values will return
    /// that value instead of the global default.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Test(.withDefaults("Test User", 42, true))
    /// func testUserService() {
    ///     let mock = MockUserService()
    ///
    ///     // These will use the custom defaults:
    ///     let name = mock.getUserName()     // Returns "Test User"
    ///     let age = mock.getUserAge()       // Returns 42
    ///     let active = mock.isUserActive()  // Returns true
    /// }
    /// ```
    ///
    /// ## Type Safety
    ///
    /// The values are type-checked at compile time, ensuring that only valid default values
    /// can be provided. Each value becomes the default for all unstubbed methods returning
    /// that specific type.
    ///
    /// - Parameter values: A variadic list of default values to be used for unstubbed mock
    ///   methods of matching types. Each value will be used as the default for its respective type.
    ///
    /// - Returns: A `DefaultValuesTrait` configured with the provided values.
    static func withDefaults<each Value>(_ values: repeat each Value) -> DefaultValuesTrait {
        var providers = [DefaultProviding]()

        for value in repeat each values {
            providers.append(DefaultProviding.valueProvider(value))
        }

        return DefaultValuesTrait(providers)
    }
}
