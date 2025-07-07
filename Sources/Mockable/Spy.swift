//
//  Spy.swift
//  Witness
//
//  Created by Daniel Cardona on 3/07/25.
//

/// A ``Spy`` is a type of test double that captures calls to its methods, allowing you to inspect them later.
///
/// You can use a ``Spy`` to verify that a method was called with specific arguments, or to check how many times it was called.
/// Spies are useful for testing interactions between objects.
///
/// You don't create spies manually. Instead, you use the ``@Mockable`` macro to generate a spy for a protocol.
public class Spy<each Input, Effects: Effect, Output> {
    private(set) var invocations: [(repeat each Input)] = []
    private var stubs: [Stub<repeat each Input, Effects, Output>] = []

    public init() { }

    func invoke(_ input: repeat each Input) throws -> Return<Output> {
        invocations.append((repeat each input))

        // search through stub for a return value
        var matchingStub: Stub<repeat each Input, Effects, Output>?

        for stub in stubs {
            if stub.invocationMatcher.isMatchedBy((repeat each input)) {
                matchingStub = stub
                break
            }
        }
        guard let returnValue = matchingStub?.output else {
            throw MockingError.unStubbed
        }

        return returnValue
    }

    public func when(calledWith matchingInput: repeat ArgMatcher<each Input>) -> Stub<repeat each Input, Effects, Output> {
        when(calledWith: InvocationMatcher(matchers: repeat each matchingInput))
    }

    public func when(calledWith invocationMatcher: InvocationMatcher <repeat each Input>) -> Stub<repeat each Input, Effects, Output> {
        let stub = Stub<repeat each Input, Effects, Output>(invocationMatcher: invocationMatcher)
        stubs.append(stub)
        return stub
    }

    public func verifyCalled(_ countMatcher: ArgMatcher<Int>? = nil) -> Bool {
        let matcher = countMatcher ?? .greaterThan(.zero)
        return matcher(invocations.count)
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

    public func verifyThrows(_ errorMatcher: ArgMatcher<any Error>) -> Bool {
        var doesThrow = false
        for invocation in invocations {
            for stub in stubs {
                if stub.invocationMatcher.isMatchedBy((repeat each invocation)) {
                    if let stubbedReturn = stub.output {
                        do {
                            try stubbedReturn.get()
                        }
                        catch {
                            doesThrow = errorMatcher(error)
                        }
                    }
                }
            }
        }
        return doesThrow
    }

    public func verifyThrows() -> Bool {
        verifyThrows(.anyError())
    }
}

// MARK: Throwing
extension Spy where Effects == Throws {
    @discardableResult
    public func call(_ input: repeat each Input) throws -> Output {
        try invoke(repeat each input).get()
    }
}

// MARK: None throwing
extension Spy where Effects == None {
    @discardableResult
    public func call(_ input: repeat each Input) -> Output {
        do {
            return try invoke(repeat each input).get()
        } catch let error as MockingError {
            fatalError("MockingError: \(error.message)")
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }

}

// MARK: Adapters

/// A helper that converts a spy into a closure that is easily assignable to a protocol witness closure property.
public func adapt<Context, each I, O>(_ keyPath: KeyPath<Context, Spy<repeat each I, None, O>>) -> (Context, repeat each I) -> O {
    { (context, input: repeat each I) -> O  in
        let spy = context[keyPath: keyPath]
        let result = spy.call(repeat each input)
        return result
    }
}

/// A helper that converts a spy into a closure that is easily assignable to a protocol witness closure property.
public func adapt<Context, each I, O>(_ keyPath: KeyPath<Context, Spy<repeat each I, Throws, O>>) -> (Context, repeat each I) throws -> O {
    { (context, input: repeat each I) -> O  in
        let spy = context[keyPath: keyPath]
        let result = try spy.call(repeat each input)
        return result
    }
}
