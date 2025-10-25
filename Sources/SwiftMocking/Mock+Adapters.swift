//
//  Mock+Adapters.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 20/07/25.
//

/// Adapter methods that bridge between generated mock methods and spy infrastructure.
///
/// These adapters are automatically called by generated mock implementations to
/// ensure proper spy configuration and invocation recording. They handle the
/// different effect types (async, throws, async throws) and ensure that the
/// mock's default provider registry is properly propagated to the spy.
public extension Mock {
    /// Adapts a synchronous spy call for static method mocking.
    ///
    /// This adapter is used by generated static mock methods to invoke the
    /// underlying spy while ensuring proper configuration inheritance.
    ///
    /// - Parameters:
    ///   - spy: The spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the spy invocation.
    static func adapt<each I, O>(_ spy: Spy<repeat each I, None, O>, _ input: repeat each I) -> O {
        spy.defaultProviderRegistry = defaultProviderRegistry
        let result = spy(repeat each input)
        return result
    }

    /// Adapts a synchronous spy call for instance method mocking.
    ///
    /// This adapter is used by generated instance mock methods to invoke the
    /// underlying spy while ensuring proper configuration inheritance.
    ///
    /// - Parameters:
    ///   - spy: The spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the spy invocation.
    func adapt<each I, O>(_ spy: Spy<repeat each I, None, O>, _ input: repeat each I) -> O {
        spy.defaultProviderRegistry = defaultProviderRegistry
        let result = spy(repeat each input)
        return result
    }

    /// Adapts an asynchronous spy call for static method mocking.
    ///
    /// This adapter handles async method calls in generated static mock methods,
    /// ensuring proper async context and configuration inheritance.
    ///
    /// - Parameters:
    ///   - spy: The async spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the async spy invocation.
    static func adapt<each I, O>(_ spy: Spy<repeat each I, Async, O>, _ input: repeat each I) async -> O {
        spy.defaultProviderRegistry = defaultProviderRegistry
        let result = await spy(repeat each input)
        return result
    }

    /// Adapts an asynchronous spy call for instance method mocking.
    ///
    /// This adapter handles async method calls in generated instance mock methods,
    /// ensuring proper async context and configuration inheritance.
    ///
    /// - Parameters:
    ///   - spy: The async spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the async spy invocation.
    func adapt<each I, O>(_ spy: Spy<repeat each I, Async, O>, _ input: repeat each I) async -> O {
        spy.defaultProviderRegistry = defaultProviderRegistry
        let result = await spy(repeat each input)
        return result
    }

    /// Adapts a throwing spy call for static method mocking.
    ///
    /// This adapter handles methods that can throw errors in generated static
    /// mock methods, ensuring proper error propagation and configuration inheritance.
    ///
    /// - Parameters:
    ///   - spy: The throwing spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the spy invocation.
    /// - Throws: Any error thrown by the spy or stubbed behavior.
    static func adaptThrowing<each I, O>(_ spy: Spy<repeat each I, Throws, O>, _ input: repeat each I) throws -> O {
        spy.defaultProviderRegistry = defaultProviderRegistry
        let result = try spy(repeat each input)
        return result
    }

    /// Adapts a throwing spy call for instance method mocking.
    ///
    /// This adapter handles methods that can throw errors in generated instance
    /// mock methods, ensuring proper error propagation and configuration inheritance.
    ///
    /// - Parameters:
    ///   - spy: The throwing spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the spy invocation.
    /// - Throws: Any error thrown by the spy or stubbed behavior.
    func adaptThrowing<each I, O>(_ spy: Spy<repeat each I, Throws, O>, _ input: repeat each I) throws -> O {
        spy.defaultProviderRegistry = defaultProviderRegistry
        let result = try spy(repeat each input)
        return result
    }

    /// Adapts an async throwing spy call for static method mocking.
    ///
    /// This adapter handles methods that are both async and throwing in generated
    /// static mock methods, ensuring proper async context, error propagation,
    /// and configuration inheritance.
    ///
    /// - Parameters:
    ///   - spy: The async throwing spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the async spy invocation.
    /// - Throws: Any error thrown by the spy or stubbed behavior.
    static func adaptThrowing<each I, O>(_ spy: Spy<repeat each I, AsyncThrows, O>, _ input: repeat each I) async throws -> O {
        spy.defaultProviderRegistry = defaultProviderRegistry
        let result = try await spy(repeat each input)
        return result
    }

    /// Adapts an async throwing spy call for instance method mocking.
    ///
    /// This adapter handles methods that are both async and throwing in generated
    /// instance mock methods, ensuring proper async context, error propagation,
    /// and configuration inheritance.
    ///
    /// - Parameters:
    ///   - spy: The async throwing spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the async spy invocation.
    /// - Throws: Any error thrown by the spy or stubbed behavior.
    func adaptThrowing<each I, O>(_ spy: Spy<repeat each I, AsyncThrows, O>, _ input: repeat each I) async throws -> O {
        spy.defaultProviderRegistry = defaultProviderRegistry
        let result = try await spy(repeat each input)
        return result
    }

}
