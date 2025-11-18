//
//  InvocationMatcher.swift
//  Mockable
//
//  Created by Daniel Cardona on 4/07/25.
//

/// A type that matches a set of arguments against a set of ``ArgMatcher``s.
///
/// This type is used to represent all parameters of a method signature.
///
/// ### Usage Example:
///
/// ```swift
/// // Create an InvocationMatcher that matches any string and an integer equal to 10
/// let matcher = InvocationMatcher(matchers: .any, .equal(10))
///
/// // Create an Invocation with actual arguments
/// let invocation = Invocation(arguments: "hello", 10)
///
/// // Check if the invocation matches the matcher
/// if matcher.isMatchedBy(invocation) {
///     print("Invocation matches!")
/// } else {
///     print("Invocation does not match.")
/// }
/// ```
public struct InvocationMatcher<each I> {
   let matchers: (repeat ArgMatcher<each I>)

    /// Initializes an `InvocationMatcher` with a variadic list of ``ArgMatcher``s.
    /// - Parameter matchers: A list of matchers, one for each argument in the method signature.
    public init(matchers: repeat ArgMatcher<each I>) {
        self.matchers = (repeat each matchers)
    }

    /// Checks if the given ``Invocation`` matches the criteria defined by this `InvocationMatcher`.
    /// - Parameter invocation: The ``Invocation`` to check against.
    /// - Returns: `true` if all arguments in the invocation match their corresponding `ArgMatcher`s, `false` otherwise.
    public func isMatchedBy(_ invocation: Invocation<repeat each I>) -> Bool {
        func match <each Element>(invocation: Invocation<repeat each Element>, matchers: (repeat ArgMatcher<each Element>)) -> Bool {
            for (input, matcher) in repeat (each invocation.arguments, each matchers) {
                guard matcher(input) else { return false }
            }
            return true
        }
        return match(invocation: invocation, matchers: (repeat each matchers))
    }

    public var precedence: Int {
        var sum = 0
        for matcher in repeat each matchers {
            sum += matcher.precedence.value
        }
        return sum
    }
}

extension InvocationMatcher: Sendable where repeat each I: Sendable { }
