//
//  Spy.swift
//  Witness
//
//  Created by Daniel Cardona on 3/07/25.
//
public class Spy<each Input, Effects: Effect, Output> {
    private(set) var invocations: [(repeat each Input)] = []
    private var stubs: [Stub<repeat each Input, Effects, Output>] = []

    public init() { }

    @discardableResult
    public func call(_ input: repeat each Input) -> Output {
        invocations.append((repeat each input))

        // search through stub for a return value
        for stub in stubs {
            if stub.invocationMatcher.isMatchedBy((repeat each input)) {
                do {
                    return try stub.get()
                } catch {
                    fatalError(String(describing: error))
                }
            }
        }

        fatalError("Unstubbed")
    }

    public func callAsFunction(_ input: repeat each Input) -> Output {
        call(repeat each input)
    }

    public func when(calledWith matchingInput: repeat ArgMatcher<each Input>) -> Stub<repeat each Input, Effects, Output> {
        let invocationMatcher = InvocationMatcher(matchers: repeat each matchingInput)
        let stub = Stub<repeat each Input, Effects, Output>(spy: self, invocationMatcher: invocationMatcher)
        stubs.append(stub)
        return stub
    }

    public func verifyCalled(_ countMatcher: ArgMatcher<Int>) -> Bool {
        countMatcher(invocations.count)
    }

    public func verify(calledWith arguments: repeat ArgMatcher<each Input>, count countMatcher: ArgMatcher<Int>) -> Bool {
        let invocationMatcher = InvocationMatcher(matchers: repeat each arguments)
        return verify(calledWith: invocationMatcher, count: countMatcher)
    }

    public func verify(calledWith invocationMatcher: InvocationMatcher<repeat each Input>, count countMatcher: ArgMatcher<Int>) -> Bool {
        var count = 0
        for invocation in invocations {
            if invocationMatcher.isMatchedBy((repeat each invocation)) {
                count += 1
            }
        }
        return countMatcher(count)
    }
}
