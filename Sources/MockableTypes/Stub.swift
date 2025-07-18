//
//  Stub.swift
//  Mockable
//
//  Created by Daniel Cardona on 4/07/25.
//

/// A ``Stub`` is a type that provides a pre-canned answer for a single method.
///
/// You use stubs to control the behavior of a dependency during a test. For example, you can stub a method to return a specific value, or to throw an error.
/// Stubs are created by calling the `when(calledWith:)` method on a ``Spy`` and are recorded to intercept invocations on a method and
/// return the programmed return value.
public class Stub<each I, Effects: Effect, O> {
    /// The ``InvocationMatcher`` that defines when this stub should be applied.
    public let invocationMatcher: InvocationMatcher<repeat each I>
    var output: ((Invocation<repeat each I>) -> Return<O>)?

    /// Initializes a `Stub` instance.
    /// - Parameter invocationMatcher: The ``InvocationMatcher`` that determines when this stub is active.
    init( invocationMatcher: InvocationMatcher<repeat each I>) {
        self.invocationMatcher = invocationMatcher
    }

    func returnValue(for invocation: Invocation<repeat each I>) -> Return<O>? {
        guard invocationMatcher.isMatchedBy(invocation) else {
            return nil
        }
        return output?(invocation)

    }

    /// Defines the return value for this stub.
    /// - Parameter output: The value to return when this stub is matched.
    public func thenReturn(_ output: O) {
        self.output = { _ in  Return.value(output) }
    }

    public func thenReturn(_ handler: @escaping (repeat each I) -> O) {
        self.output = { invocation in
            let returnValue = handler(repeat each invocation.arguments)
            return Return.value(returnValue)
        }

    }
}

extension Stub where Effects: Throwing {
    /// Defines an error to be thrown when this stub is matched.
    /// - Parameter error: The error to throw.
    public func thenThrow<E: Error>(_ error: E) {
        self.output = { _ in  Return.error(error) }
    }
}
