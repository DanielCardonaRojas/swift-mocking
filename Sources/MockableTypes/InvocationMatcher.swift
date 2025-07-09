//
//  InvocationMatcher.swift
//  Mockable
//
//  Created by Daniel Cardona on 4/07/25.
//

/// A type that matches a set of arguments against a set of ``ArgMatcher``s.
///
/// This type is used to represent all parameters of a method signature.
public struct InvocationMatcher<each I> {
   let matchers: (repeat ArgMatcher<each I>)

    public init(matchers: repeat ArgMatcher<each I>) {
        self.matchers = (repeat each matchers)
    }

    public func isMatchedBy(_ invocation: Invocation<repeat each I>) -> Bool {
        func match <each Element>(invocation: Invocation<repeat each Element>, matchers: (repeat ArgMatcher<each Element>)) -> Bool {
            for (input, matcher) in repeat (each invocation.arguments, each matchers) {
                guard matcher(input) else { return false }
            }
            return true
        }
        return match(invocation: invocation, matchers: (repeat each matchers))
    }
}

