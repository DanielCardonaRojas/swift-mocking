//
//  Stub.swift
//  Mockable
//
//  Created by Daniel Cardona on 4/07/25.
//

/// A ``Stub`` is a test double that provides pre-canned answers to method calls.
///
/// You use stubs to control the behavior of a dependency during a test. For example, you can stub a method to return a specific value, or to throw an error.
/// Stubs are created by calling the `when(calledWith:)` method on a ``Spy``.
public class Stub<each I, Effects: Effect, O> {
    public let invocationMatcher: InvocationMatcher<repeat each I>
    var output: Return<O>?

    init( invocationMatcher: InvocationMatcher<repeat each I>) {
        self.invocationMatcher = invocationMatcher
    }

    func get() throws -> O {
        guard let output else {
            throw MockingError.unStubbed
        }
        return try output.get()
    }

    public func thenReturn(_ output: O) {
        self.output = Return.value(output)
    }
}

extension Stub where Effects == Throws {
    public func thenThrow<E: Error>(_ error: E) {
        self.output = Return.error(error)
    }
}
