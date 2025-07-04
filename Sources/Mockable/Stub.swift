//
//  Stub.swift
//  Mockable
//
//  Created by Daniel Cardona on 4/07/25.
//

public class Stub<each I, O> {
    let spy: Spy<repeat each I, O>
    let invocationMatcher: InvocationMatcher<repeat each I>
    var output: O?

    init(spy: Spy<repeat each I, O>, invocationMatcher: InvocationMatcher<repeat each I>) {
        self.invocationMatcher = invocationMatcher
        self.spy = spy
    }

    func get() throws -> O {
        guard let output else {
            throw MockingError(message: "Unstubbed")
        }
        return output
    }

    public func thenReturn(_ output: O) {
        self.output = output
    }
}
