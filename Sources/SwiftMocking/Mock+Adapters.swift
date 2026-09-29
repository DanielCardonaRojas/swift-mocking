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
/// The adapters take no source location. A conformance witness must match the protocol
/// requirement's signature exactly, so the generated method cannot carry defaulted
/// location parameters:
///
/// ```swift
/// protocol P { func f(_ x: Int) -> Int }
/// // error: type 'Impl' does not conform to protocol 'P'
/// struct Impl: P { func f(_ x: Int, fileID: StaticString = #fileID) -> Int { x } }
/// ```
///
/// An unstubbed non-throwing requirement therefore traps without a caller-supplied
/// location. What keeps that trap useful is `@_transparent`: it inlines these adapters
/// into the generated conformance before the optimizer runs, so the debugger attributes
/// the trap to the mock's own method rather than to a frame inside SwiftMocking. See
/// ``reportUnrecoverable``.
///
/// Every adapter carries `@_transparent`, not just the trapping ones. The throwing
/// adapters surface an unstubbed call as a thrown error rather than a trap, but they are
/// not trap-free:
///
/// - the typed-throwing adapters reach ``Spy/narrow(_:location:)``, which *does* trap,
///   because a ``MockingError`` cannot cross a `throws(Failure)` boundary;
/// - any adapter can trap by way of a stubbed handler or a registered action.
///
/// In each case the generated conformance is the frame the user needs to see, and an
/// opaque adapter frame between it and the trap is what would hide it. Leaving the
/// attribute off the throwing adapters also made the two groups differ for a reason that
/// did not survive typed throws being added.
public extension Mock {
    /// Adapts a synchronous spy call for static method mocking.
    ///
    /// - Parameters:
    ///   - spy: The spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the spy invocation.
    @_transparent
    static func adapt<each I, O>(
        _ spy: Spy<repeat each I, None, O>,
        _ input: repeat each I
    ) -> O {
        do {
            return try spy.process(repeat each input)
        } catch {
            reportUnrecoverable(error)
        }
    }

    /// Adapts a synchronous spy call for instance method mocking.
    ///
    /// - Parameters:
    ///   - spy: The spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the spy invocation.
    @_transparent
    func adapt<each I, O>(
        _ spy: Spy<repeat each I, None, O>,
        _ input: repeat each I
    ) -> O {
        do {
            return try spy.process(repeat each input)
        } catch {
            reportUnrecoverable(error)
        }
    }

    /// Adapts an asynchronous spy call for static method mocking.
    ///
    /// - Parameters:
    ///   - spy: The async spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the async spy invocation.
    @_transparent
    static func adapt<each I, O>(
        _ spy: Spy<repeat each I, Async, O>,
        _ input: repeat each I
    ) async -> O {
        do {
            return try await spy.process(repeat each input)
        } catch {
            reportUnrecoverable(error)
        }
    }

    /// Adapts an asynchronous spy call for instance method mocking.
    ///
    /// - Parameters:
    ///   - spy: The async spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the async spy invocation.
    @_transparent
    func adapt<each I, O>(
        _ spy: Spy<repeat each I, Async, O>,
        _ input: repeat each I
    ) async -> O {
        do {
            return try await spy.process(repeat each input)
        } catch {
            reportUnrecoverable(error)
        }
    }

    /// Adapts a throwing spy call for static method mocking.
    ///
    /// An unstubbed requirement reports and traps here, exactly as it does for the
    /// non-throwing adapters — see ``Spy/process(_:location:)``. The requirement's ability
    /// to throw is not used for it: relying on a thrown ``MockingError`` meant an unstubbed
    /// call vanished whenever the caller caught broadly (`try?`, or a `catch` mapping every
    /// error to a default), turning a missing stub into a silently wrong test.
    ///
    /// A *stubbed* error still propagates through the `throws` clause as normal.
    ///
    /// - Parameters:
    ///   - spy: The throwing spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the spy invocation.
    /// - Throws: Any error thrown by the spy or stubbed behavior.
    @_transparent
    static func adaptThrowing<each I, O>(
        _ spy: Spy<repeat each I, Throws, O>,
        _ input: repeat each I,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) throws -> O {
        return try spy(
            repeat each input,
            fileID: fileID, filePath: filePath, line: line, column: column
        )
    }

    /// Adapts a throwing spy call for instance method mocking.
    ///
    /// - Parameters:
    ///   - spy: The throwing spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the spy invocation.
    /// - Throws: Any error thrown by the spy or stubbed behavior.
    @_transparent
    func adaptThrowing<each I, O>(
        _ spy: Spy<repeat each I, Throws, O>,
        _ input: repeat each I,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) throws -> O {
        return try spy(
            repeat each input,
            fileID: fileID, filePath: filePath, line: line, column: column
        )
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
    @_transparent
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
    @_transparent
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
    @_transparent
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
    @_transparent
    func adaptAsyncTypedThrowing<each I, E: Error, O>(
        _ spy: Spy<repeat each I, AsyncTypedThrows<E>, O>,
        _ input: repeat each I
    ) async throws(E) -> O {
        try await spy(repeat each input)
    }

    /// Adapts an async throwing spy call for static method mocking.
    ///
    /// - Parameters:
    ///   - spy: The async throwing spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the async spy invocation.
    /// - Throws: Any error thrown by the spy or stubbed behavior.
    @_transparent
    static func adaptThrowing<each I, O>(
        _ spy: Spy<repeat each I, AsyncThrows, O>,
        _ input: repeat each I,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) async throws -> O {
        return try await spy(
            repeat each input,
            fileID: fileID, filePath: filePath, line: line, column: column
        )
    }

    /// Adapts an async throwing spy call for instance method mocking.
    ///
    /// - Parameters:
    ///   - spy: The async throwing spy instance to invoke.
    ///   - input: The input arguments to pass to the spy.
    /// - Returns: The result of the async spy invocation.
    /// - Throws: Any error thrown by the spy or stubbed behavior.
    @_transparent
    func adaptThrowing<each I, O>(
        _ spy: Spy<repeat each I, AsyncThrows, O>,
        _ input: repeat each I,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) async throws -> O {
        return try await spy(
            repeat each input,
            fileID: fileID, filePath: filePath, line: line, column: column
        )
    }
}
