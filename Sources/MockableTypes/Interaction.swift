//
//  Interaction.swift
//  Mockable
//
//  Created by Daniel Cardona on 6/07/25.
//

/// Represents a specific interaction with a mock object, combining an ``InvocationMatcher`` and a ``Spy``.
///
/// This struct is primarily used internally by the Mockable framework and in conjunction with the `when` and `verify` functions
/// provided by the `XCTestCase+Extensions.swift` to define stubbing behavior or verify method calls.
public struct Interaction<each Input, Eff: Effect, Output> {
    /// The matcher that defines the arguments for this interaction.
    public let invocationMatcher: InvocationMatcher<repeat each Input>
    /// The spy associated with this interaction.
    public let spy: Spy<repeat each Input, Eff, Output>

    /// Initializes an `Interaction` instance.
    /// - Parameters:
    ///   - matchers: A variadic list of ``ArgMatcher``s, one for each input parameter of the method.
    ///   - spy: The ``Spy`` instance that this interaction is associated with.
    public init(_ matchers: repeat ArgMatcher<each Input>, spy: Spy<repeat each Input, Eff, Output>) {
        self.invocationMatcher = InvocationMatcher(matchers: repeat each matchers)
        self.spy = spy
    }

    public func invocations() -> [(repeat each Input)]{
        var arguments = [(repeat each Input)]()
        for invocation in spy.invocations {
            if invocationMatcher.isMatchedBy(invocation) {
                arguments.append(invocation.arguments)
            }
        }
        return arguments
    }
}

