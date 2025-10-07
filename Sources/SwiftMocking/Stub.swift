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
    var output: ((Invocation<repeat each I>) -> Return<Effects, O>)?

    /// Initializes a `Stub` instance.
    /// - Parameter invocationMatcher: The ``InvocationMatcher`` that determines when this stub is active.
    init( invocationMatcher: InvocationMatcher<repeat each I>) {
        self.invocationMatcher = invocationMatcher
    }

    func returnValue(for invocation: Invocation<repeat each I>) -> Return<Effects, O>? {
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

    /// The precedence of this stub based on its invocation matcher.
    ///
    /// Stubs with higher precedence are matched first when multiple stubs
    /// could apply to the same method call. This ensures that more specific
    /// matchers take priority over general ones.
    public var precedence: MatcherPrecedence {
        .init(value: invocationMatcher.precedence)
    }
}

extension Stub where Effects == None {
    /// Defines a dynamic return value using a closure that receives the method arguments.
    ///
    /// This allows you to create stubs with behavior that depends on the actual
    /// arguments passed to the method. The closure receives the same arguments
    /// as the original method and can compute a return value based on them.
    ///
    /// Example:
    /// ```swift
    /// when(mock.calculate(a: .any, b: .any)).thenReturn { a, b in
    ///     return a + b  // Dynamic calculation based on arguments
    /// }
    /// ```
    ///
    /// - Parameter handler: A closure that takes the method arguments and returns the desired output.
    public func thenReturn(_ handler: @escaping (repeat each I) -> O) {
        self.output = { invocation in
            let returnValue = handler(repeat each invocation.arguments)
            return Return.value(returnValue)
        }
    }

    /// Defines a dynamic return value using a closure that receives the method arguments.
    ///
    /// This is an alias for `thenReturn(_:)` that provides a more concise syntax
    /// for dynamic stubbing scenarios.
    ///
    /// Example:
    /// ```swift
    /// when(mock.calculate(a: .any, b: .any)).then { a, b in
    ///     return a * b  // Dynamic calculation
    /// }
    /// ```
    ///
    /// - Parameter handler: A closure that takes the method arguments and returns the desired output.
    public func then(_ handler: @escaping (repeat each I) -> O) {
        thenReturn(handler)
    }
}

extension Stub where Effects: Throwing {
    /// Defines an error to be thrown when this stub is matched.
    /// - Parameter error: The error to throw.
    public func thenThrow<E: Error>(_ error: E) {
        self.output = { _ in  Return.error(error) }
    }

    /// Defines a dynamic return value that can throw before producing the result.
    /// - Parameter handler: A closure that can throw and returns the desired output.
    public func thenReturn(_ handler: @escaping (repeat each I) throws -> O) {
        self.output = { invocation in
            Return(value: {
                do {
                    let returnValue = try handler(repeat each invocation.arguments)
                    return .success(returnValue)
                } catch {
                    return .failure(error)
                }
            })
        }
    }
}

extension Stub where Effects: Asynchronous {
    /// Defines a dynamic return value using an asynchronous closure.
    /// - Parameter handler: An async closure that returns the desired output.
    public func thenReturn(_ handler: @escaping (repeat each I) async -> O) {
        self.output = { invocation in
            Return(asyncValue: {
                let returnValue = await handler(repeat each invocation.arguments)
                return .success(returnValue)
            })
        }
    }
}

extension Stub where Effects: Asynchronous, Effects: Throwing {
    /// Defines a dynamic return value using an asynchronous closure that can throw.
    /// - Parameter handler: An async closure that returns the desired output or throws.
    public func thenReturn(_ handler: @escaping (repeat each I) async throws -> O) {
        self.output = { invocation in
            Return(asyncValue: {
                do {
                    let returnValue = try await handler(repeat each invocation.arguments)
                    return .success(returnValue)
                } catch {
                    return .failure(error)
                }
            })
        }
    }
}
