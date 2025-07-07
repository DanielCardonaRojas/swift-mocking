//
//  Interaction.swift
//  Mockable
//
//  Created by Daniel Cardona on 6/07/25.
//

public struct Interaction<each Input, Eff: Effect, Output> {
    public let invocationMatcher: InvocationMatcher<repeat each Input>
    public let spy: Spy<repeat each Input, Eff, Output>

    public init(_ matchers: repeat ArgMatcher<each Input>, spy: Spy<repeat each Input, Eff, Output>) {
        self.invocationMatcher = InvocationMatcher(matchers: repeat each matchers)
        self.spy = spy
    }
}

