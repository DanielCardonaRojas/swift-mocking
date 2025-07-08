//
//  Assert.swift
//  Mockable
//
//  Created by Daniel Cardona on 6/07/25.
//

public class Assert<each Input, Eff: Effect, Output> {
    var invocationMatcher: InvocationMatcher<repeat each Input>?
    unowned var spy: Spy<repeat each Input, Eff, Output>
    public init(
        invocationMatcher: InvocationMatcher<repeat each Input>? = nil,
        spy: Spy<repeat each Input, Eff, Output>
    ) {
        self.invocationMatcher = invocationMatcher
        self.spy = spy
    }

    func assert(_ matcher: ArgMatcher<Int>?) throws {
        let countMatcher = matcher ?? .greaterThan(.zero)
        let count = if let invocationMatcher { spy.invocationCount(matching: invocationMatcher) } else { spy.invocations.count }
        if !countMatcher(count) {
            throw MockingError.unfulfilledCallCount(count)
        }
    }
}
