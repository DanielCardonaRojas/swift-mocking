//
//  InvocationMatcher.swift
//  Mockable
//
//  Created by Daniel Cardona on 4/07/25.
//

public struct InvocationMatcher<each I> {
    let matchers: (repeat ArgMatcher<each I>)

    init(matchers: repeat ArgMatcher<each I>) {
        self.matchers = (repeat each matchers)
    }

    func isMatchedBy(_ invocation: (repeat each I)) -> Bool {
        func match <each Element>(inputs: (repeat each Element), matchers: (repeat ArgMatcher<each Element>)) -> Bool {
          for (input, matcher) in repeat (each inputs, each matchers) {
            guard matcher(input) else { return false }
          }
          return true
        }
        return match(inputs: (repeat each invocation), matchers: (repeat each matchers))
    }
}

