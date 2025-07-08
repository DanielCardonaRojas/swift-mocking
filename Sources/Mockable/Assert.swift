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

    public func doesThrow(_ errorMatcher: ArgMatcher<any Error>? = nil) throws {
        var errors = [any Error]()
        for invocation in spy.invocations {
            for stub in spy.stubs {
                // Is there is no programmed `Return` for this stub don't even bother trying to match
                guard let stubbedReturn = stub.output else { continue }

                if stub.invocationMatcher.isMatchedBy(invocation) { // Found a candidate

                    if let invocationMatcher {
                        // If an invocation matcher is non nil than it also needs to match
                        if invocationMatcher.isMatchedBy(invocation) {
                            try Self.collectErrors(stubbedReturn, errors: &errors)
                        }
                    } else {
                        try Self.collectErrors(stubbedReturn, errors: &errors)
                    }
                }
            }
        }

        if errors.isEmpty {
            throw MockingError.didNotThrow
        }

        if let errorMatcher, !errors.contains(where: errorMatcher.callAsFunction) {
            throw MockingError.didNotMatchThrown(errors)
        }

        return
    }

    private static func collectErrors<O>(_ result: Return<O>, errors: inout [any Error]) throws {
        do {
            _ = try result.get()
        } catch {
            errors.append(error)
        }
    }
}
