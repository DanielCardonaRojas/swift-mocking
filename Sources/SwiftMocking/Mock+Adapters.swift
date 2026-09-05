//
//  Mock+Adapters.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 20/07/25.
//

import Foundation

/// Adapter methods that bridge between generated mock methods and spy infrastructure.
///
/// These adapters are automatically called by generated mock implementations to route
/// calls through the spy infrastructure. They handle the different effect types
/// (async, throws, async throws). The mock's default provider registry is captured by
/// each spy once, at creation time (in `Mock`'s subscript), not re-applied per call.
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
    @inlinable
    @inline(__always)
    static func adapt<each I, O>(_ spy: Spy<repeat each I, None, O>, _ input: repeat each I) -> O {
        do {
            return try spy.process(repeat each input)
        } catch let error as MockingError {
            fatalError("MockingError: \(error.message)")
        } catch {
            fatalError("\(error.localizedDescription)")
        }
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
    @inlinable
    @inline(__always)
    func adapt<each I, O>(_ spy: Spy<repeat each I, None, O>, _ input: repeat each I) -> O {
        do {
            return try spy.process(repeat each input)
        } catch let error as MockingError {
            fatalError("MockingError: \(error.message)")
        } catch {
            fatalError("\(error.localizedDescription)")
        }
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
    @inlinable
    @inline(__always)
    static func adapt<each I, O>(_ spy: Spy<repeat each I, Async, O>, _ input: repeat each I) async -> O {
        do {
            return try await spy.process(repeat each input)
        } catch let error as MockingError {
            fatalError("MockingError: \(error.message)")
        } catch {
            fatalError("\(error.localizedDescription)")
        }
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
    @inlinable
    @inline(__always)
    func adapt<each I, O>(_ spy: Spy<repeat each I, Async, O>, _ input: repeat each I) async -> O {
        do {
            return try await spy.process(repeat each input)
        } catch let error as MockingError {
            fatalError("MockingError: \(error.message)")
        } catch {
            fatalError("\(error.localizedDescription)")
        }
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
        let result = try spy(repeat each input)
        return result
    }

    /// Adapts a typed-throwing spy call for static method mocking.
    ///
    /// The declared error type flows from the spy's effect into this adapter's
    /// `throws(E)` clause, so the generated conformance keeps the requirement's
    /// typed-throws signature instead of widening it to `any Error`.
    ///
    /// Named distinctly from ``adaptThrowing(_:_:)`` rather than overloading it: the
    /// spy argument comes from `Mock`'s generic `@dynamicMemberLookup` subscript, so
    /// nothing anchors `Eff` at the call site and the effect is inferred *from* the
    /// adapter's parameter. With both spelled `adaptThrowing`, the solver has no basis
    /// to prefer the typed overload and picks the untyped one, producing
    /// `error: thrown expression type 'any Error' cannot be converted to error type 'E'`
    /// inside the expansion. A separate name makes the generator's choice explicit.
    ///
    /// - Parameters:
    ///   - spy: The typed-throwing spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the spy invocation.
    /// - Throws: The stubbed error, typed as `E`.
    static func adaptTypedThrowing<each I, E: Error, O>(
        _ spy: Spy<repeat each I, TypedThrows<E>, O>,
        _ input: repeat each I
    ) throws(E) -> O {
        try spy(repeat each input)
    }

    /// Adapts a typed-throwing spy call for instance method mocking.
    ///
    /// See the static overload for how the declared error type is preserved and why
    /// this is not an `adaptThrowing` overload.
    ///
    /// - Parameters:
    ///   - spy: The typed-throwing spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the spy invocation.
    /// - Throws: The stubbed error, typed as `E`.
    func adaptTypedThrowing<each I, E: Error, O>(
        _ spy: Spy<repeat each I, TypedThrows<E>, O>,
        _ input: repeat each I
    ) throws(E) -> O {
        try spy(repeat each input)
    }

    /// Adapts an async typed-throwing spy call for static method mocking.
    ///
    /// See ``adaptTypedThrowing(_:_:)`` for how the declared error type is preserved.
    ///
    /// - Parameters:
    ///   - spy: The async typed-throwing spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the async spy invocation.
    /// - Throws: The stubbed error, typed as `E`.
    static func adaptAsyncTypedThrowing<each I, E: Error, O>(
        _ spy: Spy<repeat each I, AsyncTypedThrows<E>, O>,
        _ input: repeat each I
    ) async throws(E) -> O {
        try await spy(repeat each input)
    }

    /// Adapts an async typed-throwing spy call for instance method mocking.
    ///
    /// See the static overload for how the declared error type is preserved.
    ///
    /// - Parameters:
    ///   - spy: The async typed-throwing spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the async spy invocation.
    /// - Throws: The stubbed error, typed as `E`.
    func adaptAsyncTypedThrowing<each I, E: Error, O>(
        _ spy: Spy<repeat each I, AsyncTypedThrows<E>, O>,
        _ input: repeat each I
    ) async throws(E) -> O {
        try await spy(repeat each input)
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
        let result = try await spy(repeat each input)
        return result
    }

}
