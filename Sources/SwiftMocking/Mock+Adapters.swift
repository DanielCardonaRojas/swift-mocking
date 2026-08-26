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
///
/// ## Source location
///
/// Each adapter takes a trailing `fileID`/`filePath`/`line`/`column` group describing
/// where the mocked requirement is declared. The generated conformance passes `#fileID`,
/// `#filePath`, `#line`, and `#column` explicitly, and because those literals are expanded
/// inside the macro's output — which is attached to the user's `@Mockable` protocol — they
/// resolve to that protocol's own source file and line.
///
/// This is deliberately *not* the call site of the mocked method. A conformance witness
/// must match the protocol requirement's signature exactly, so extra defaulted parameters
/// on the generated method would break conformance:
///
/// ```swift
/// protocol P { func f(_ x: Int) -> Int }
/// // error: type 'Impl' does not conform to protocol 'P'
/// struct Impl: P { func f(_ x: Int, fileID: StaticString = #fileID) -> Int { x } }
/// ```
///
/// Pointing at the protocol declaration is therefore the closest attribution available for
/// requirements invoked from production code, and it is strictly better than the previous
/// behavior of pointing inside SwiftMocking itself.
public extension Mock {
    /// Adapts a synchronous spy call for static method mocking.
    ///
    /// - Parameters:
    ///   - spy: The spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    ///   - fileID: Where the mocked requirement is declared.
    ///   - filePath: Where the mocked requirement is declared.
    ///   - line: Where the mocked requirement is declared.
    ///   - column: Where the mocked requirement is declared.
    /// - Returns: The result of the spy invocation.
    @inlinable
    @inline(__always)
    static func adapt<each I, O>(
        _ spy: Spy<repeat each I, None, O>,
        _ input: repeat each I,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) -> O {
        do {
            return try spy.process(repeat each input)
        } catch {
            reportUnrecoverable(
                error,
                fileID: fileID,
                filePath: filePath,
                line: line,
                column: column
            )
        }
    }

    /// Adapts a synchronous spy call for instance method mocking.
    ///
    /// - Parameters:
    ///   - spy: The spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    ///   - fileID: Where the mocked requirement is declared.
    ///   - filePath: Where the mocked requirement is declared.
    ///   - line: Where the mocked requirement is declared.
    ///   - column: Where the mocked requirement is declared.
    /// - Returns: The result of the spy invocation.
    @inlinable
    @inline(__always)
    func adapt<each I, O>(
        _ spy: Spy<repeat each I, None, O>,
        _ input: repeat each I,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) -> O {
        do {
            return try spy.process(repeat each input)
        } catch {
            reportUnrecoverable(
                error,
                fileID: fileID,
                filePath: filePath,
                line: line,
                column: column
            )
        }
    }

    /// Adapts an asynchronous spy call for static method mocking.
    ///
    /// - Parameters:
    ///   - spy: The async spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    ///   - fileID: Where the mocked requirement is declared.
    ///   - filePath: Where the mocked requirement is declared.
    ///   - line: Where the mocked requirement is declared.
    ///   - column: Where the mocked requirement is declared.
    /// - Returns: The result of the async spy invocation.
    @inlinable
    @inline(__always)
    static func adapt<each I, O>(
        _ spy: Spy<repeat each I, Async, O>,
        _ input: repeat each I,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) async -> O {
        do {
            return try await spy.process(repeat each input)
        } catch {
            reportUnrecoverable(
                error,
                fileID: fileID,
                filePath: filePath,
                line: line,
                column: column
            )
        }
    }

    /// Adapts an asynchronous spy call for instance method mocking.
    ///
    /// - Parameters:
    ///   - spy: The async spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    ///   - fileID: Where the mocked requirement is declared.
    ///   - filePath: Where the mocked requirement is declared.
    ///   - line: Where the mocked requirement is declared.
    ///   - column: Where the mocked requirement is declared.
    /// - Returns: The result of the async spy invocation.
    @inlinable
    @inline(__always)
    func adapt<each I, O>(
        _ spy: Spy<repeat each I, Async, O>,
        _ input: repeat each I,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) async -> O {
        do {
            return try await spy.process(repeat each input)
        } catch {
            reportUnrecoverable(
                error,
                fileID: fileID,
                filePath: filePath,
                line: line,
                column: column
            )
        }
    }

    /// Adapts a throwing spy call for static method mocking.
    ///
    /// Unlike the non-throwing adapters, an unstubbed requirement here surfaces as a thrown
    /// ``MockingError`` carrying the full message, so no issue is reported separately: the
    /// test framework already surfaces the error where the caller's `try` is caught. Adding
    /// a second report would duplicate the failure without adding information.
    ///
    /// - Parameters:
    ///   - spy: The throwing spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the spy invocation.
    /// - Throws: Any error thrown by the spy or stubbed behavior.
    static func adaptThrowing<each I, O>(
        _ spy: Spy<repeat each I, Throws, O>,
        _ input: repeat each I
    ) throws -> O {
        return try spy(repeat each input)
    }

    /// Adapts a throwing spy call for instance method mocking.
    ///
    /// - Parameters:
    ///   - spy: The throwing spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the spy invocation.
    /// - Throws: Any error thrown by the spy or stubbed behavior.
    func adaptThrowing<each I, O>(
        _ spy: Spy<repeat each I, Throws, O>,
        _ input: repeat each I
    ) throws -> O {
        return try spy(repeat each input)
    }

    /// Adapts an async throwing spy call for static method mocking.
    ///
    /// - Parameters:
    ///   - spy: The async throwing spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the async spy invocation.
    /// - Throws: Any error thrown by the spy or stubbed behavior.
    static func adaptThrowing<each I, O>(
        _ spy: Spy<repeat each I, AsyncThrows, O>,
        _ input: repeat each I
    ) async throws -> O {
        return try await spy(repeat each input)
    }

    /// Adapts an async throwing spy call for instance method mocking.
    ///
    /// - Parameters:
    ///   - spy: The async throwing spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the async spy invocation.
    /// - Throws: Any error thrown by the spy or stubbed behavior.
    func adaptThrowing<each I, O>(
        _ spy: Spy<repeat each I, AsyncThrows, O>,
        _ input: repeat each I
    ) async throws -> O {
        return try await spy(repeat each input)
    }
}
