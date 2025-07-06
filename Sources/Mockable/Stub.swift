//
//  Stub.swift
//  Mockable
//
//  Created by Daniel Cardona on 4/07/25.
//


public class Stub<each I, Effects: Effect, O> {
    let spy: Spy<repeat each I, Effects, O>
    let invocationMatcher: InvocationMatcher<repeat each I>
    var output: Return<O>?

    init(spy: Spy<repeat each I, Effects, O>, invocationMatcher: InvocationMatcher<repeat each I>) {
        self.invocationMatcher = invocationMatcher
        self.spy = spy
    }

    func get() throws -> O {
        guard let output else {
            throw MockingError(message: "Unstubbed")
        }
        return try output.get()
    }

    public func thenReturn(_ output: O) {
        self.output = Return.value(output)
    }
}

extension Stub where Effects == Throws {
    public func thenThrow<E: Error>(_ error: E) {
        self.output = Return.error(error)
    }
}
