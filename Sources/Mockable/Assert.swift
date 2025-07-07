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

    func inspect(_ matcher: ArgMatcher<Int> = .greaterThan(.zero)) -> Bool {
        if let invocationMatcher {
            spy.verify(calledWith: invocationMatcher, count: matcher)
        } else {
            spy.verifyCalled(matcher)
        }
    }
}
