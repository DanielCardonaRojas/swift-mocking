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
