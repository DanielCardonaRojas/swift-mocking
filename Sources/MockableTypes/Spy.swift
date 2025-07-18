//
//  Spy.swift
//  Witness
//
//  Created by Daniel Cardona on 3/07/25.
//
import Foundation

protocol AnySpy: AnyObject {
    var defaultProviderRegistry: DefaultProvidableRegistry? { get set }
    var invocationCount: Int { get }
    var isLoggingEnabled: Bool { get set }
    func clear()
}

/// A ``Spy`` is a type that captures calls to a single method, enabling inspections.
///
/// You can use a ``Spy`` to verify that a method was called with specific arguments, or to check how many times it was called.
/// Spies are useful for testing interactions between objects.
///
/// You don't create spies manually. Instead, you use the `@Mockable` macro to generate a spy for a protocol, or a `Mock` to create them
/// through dynamic member lookup subscripts.
public class Spy<each Input, Effects: Effect, Output>: AnySpy {
    /// A publicly accessible array of all ``Invocation``s captured by this spy.
    public private(set) var invocations: [Invocation<repeat each Input>] = []
    public var isLoggingEnabled: Bool = false

    private(set) var stubs: [Stub<repeat each Input, Effects, Output>] = []
    var defaultProviderRegistry: DefaultProvidableRegistry?
    var logger: ((Invocation<repeat each Input>) -> Void)?
    var invocationCount: Int {
        invocations.count
    }

    func configureLogger(label: String) {
        logger = { invocation in
            print("\(label)\(invocation.debugDescription)")
        }
    }

    /// Initializes a new `Spy` instance.
    public init() {
        self.configureLogger(label: "")
    }

    /// Records an invocation and attempts to find a matching stub to return a value or throw an error.
    /// - Parameter input: The arguments of the invocation.
    /// - Returns: The ``Return`` value from the matching stub.
    /// - Throws: ``MockingError/unStubbed`` if no matching stub is found.
    func invoke(_ input: repeat each Input) throws -> Return<Output> {
        let invocation = Invocation(arguments: repeat each input)
        invocations.append(invocation)

        // Log invocations
        if isLoggingEnabled {
            logger?(invocation)
        }

        // search through stub for a return value
        var matchingStub: Stub<repeat each Input, Effects, Output>?

        for stub in stubs {
            if stub.invocationMatcher.isMatchedBy(Invocation(arguments: repeat each input)) {
                matchingStub = stub
                break
            }
        }
        guard let returnValue = matchingStub?.returnValue(for: invocation) else {
            if let fallback = defaultProviderRegistry?.getDefaultForType(Output.self) {
                return .value(fallback)
            }

            throw MockingError.unStubbed
        }

        return returnValue
    }

    /// Defines a stubbing behavior for the spy when called with specific argument matchers.
    /// - Parameter matchingInput: A variadic list of ``ArgMatcher``s to match the input arguments.
    /// - Returns: A ``Stub`` instance to configure the return value or error.
    public func when(calledWith matchingInput: repeat ArgMatcher<each Input>) -> Stub<repeat each Input, Effects, Output> {
        when(calledWith: InvocationMatcher(matchers: repeat each matchingInput))
    }

    /// Defines a stubbing behavior for the spy when called with a specific invocation matcher.
    /// - Parameter invocationMatcher: An ``InvocationMatcher`` to match the input arguments.
    /// - Returns: A ``Stub`` instance to configure the return value or error.
    public func when(calledWith invocationMatcher: InvocationMatcher <repeat each Input>) -> Stub<repeat each Input, Effects, Output> {
        let stub = Stub<repeat each Input, Effects, Output>(invocationMatcher: invocationMatcher)
        stubs.append(stub)
        return stub
    }

    /// Verifies that the spy's method was called at least once.
    /// - Parameter countMatcher: An optional ``ArgMatcher`` for `Int` to specify the expected call count. If `nil`, verifies at least one call.
    /// - Returns: `true` if the call count matches the criteria, `false` otherwise.
    public func verifyCalled(_ countMatcher: ArgMatcher<Int>? = nil) -> Bool {
        let matcher = countMatcher ?? .greaterThan(.zero)
        return matcher(invocations.count)
    }

    /// Verifies that the spy's method was called with specific arguments and a specific call count.
    /// - Parameters:
    ///   - arguments: A variadic list of ``ArgMatcher``s to match the input arguments.
    ///   - countMatcher: An ``ArgMatcher`` for `Int` to specify the expected call count.
    /// - Returns: `true` if the call matches the criteria, `false` otherwise.
    public func verify(calledWith arguments: repeat ArgMatcher<each Input>, count countMatcher: ArgMatcher<Int>) -> Bool {
        let invocationMatcher = InvocationMatcher(matchers: repeat each arguments)
        return verify(calledWith: invocationMatcher, count: countMatcher)
    }

    /// Verifies that the spy's method was called with a specific invocation matcher and a specific call count.
    /// - Parameters:
    ///   - invocationMatcher: An ``InvocationMatcher`` to match the input arguments.
    ///   - countMatcher: An ``ArgMatcher`` for `Int` to specify the expected call count.
    /// - Returns: `true` if the call matches the criteria, `false` otherwise.
    public func verify(calledWith invocationMatcher: InvocationMatcher<repeat each Input>, count countMatcher: ArgMatcher<Int>) -> Bool {
        let count = invocationCount(matching: invocationMatcher)
        return countMatcher(count)
    }

    /// Returns the number of invocations that match the given invocation matcher.
    /// - Parameter invocationMatcher: The ``InvocationMatcher`` to count matching invocations.
    /// - Returns: The number of matching invocations.
    func invocationCount(matching invocationMatcher: InvocationMatcher<repeat each Input>) -> Int {
        var count = 0
        for invocation in invocations {
            if invocationMatcher.isMatchedBy(invocation) {
                count += 1
            }
        }
        return count
    }

    /// Verifies that a sequence of method calls occurred in the specified order.
    /// - Parameter invocationMatchers: An array of ``InvocationMatcher``s representing the expected sequence of calls.
    /// - Returns: `true` if the sequence of calls occurred in order, `false` otherwise.
    public func verifyInOrder(_ invocationMatchers: [InvocationMatcher<repeat each Input>]) -> Bool {
        var index = 0
        var count = 0
        for invocation in invocations {
            if index >= invocationMatchers.count {
                return false 
            }
            let invocationMatcher = invocationMatchers[index]
            if invocationMatcher.isMatchedBy(invocation) {
                index += 1
                count += 1
            }
        }

        return count == invocationMatchers.count
    }

    /// Verifies that the spy's method threw an error matching the given `errorMatcher`.
    /// - Parameter errorMatcher: An ``ArgMatcher`` for `Error` to specify the expected error.
    /// - Returns: `true` if a matching error was thrown, `false` otherwise.
    public func verifyThrows(_ errorMatcher: ArgMatcher<any Error>) -> Bool {
        var doesThrow = false
        for invocation in invocations {
            for stub in stubs {
                if stub.invocationMatcher.isMatchedBy(invocation) {
                    if let stubbedReturn = stub.returnValue(for: invocation) {
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

    /// Verifies that the spy's method threw any error.
    /// - Returns: `true` if any error was thrown, `false` otherwise.
    public func verifyThrows() -> Bool {
        verifyThrows(.anyError())
    }

    /// Clear stubs and invocations,  leaving the spy in a fresh state.
    public func clear() {
        stubs = []
        invocations = []
    }
}

// MARK: Throwing
extension Spy where Effects == Throws {
    /// Calls the spy's method, expecting it to throw an error.
    /// - Parameter input: The arguments for the method call.
    /// - Returns: The output of the method if it doesn't throw.
    /// - Throws: The error thrown by the method.
    @discardableResult
    public func call(_ input: repeat each Input) throws -> Output {
        try invoke(repeat each input).get()
    }
}

// MARK: None throwing
extension Spy where Effects == None {
    /// Calls the spy's method, expecting it not to throw an error.
    /// - Parameter input: The arguments for the method call.
    /// - Returns: The output of the method.
    /// - FatalError: If the method throws an error.
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

// MARK: Async
extension Spy where Effects == Async {
    /// Calls the spy's method asynchronously.
    /// - Parameter input: The arguments for the method call.
    /// - Returns: The output of the method.
    /// - FatalError: If the method throws an error, as `Async` effects are not expected to throw.
    @discardableResult
    public func call(_ input: repeat each Input) async -> Output {
        do {
            return try invoke(repeat each input).get()
        } catch let error as MockingError {
            fatalError("MockingError: \(error.message)")
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }
}

// MARK: AsyncThrows
extension Spy where Effects == AsyncThrows {
    /// Calls the spy's method asynchronously, allowing it to throw an error.
    /// - Parameter input: The arguments for the method call.
    /// - Returns: The output of the method if it doesn't throw.
    /// - Throws: The error thrown by the method.
    @discardableResult
    public func call(_ input: repeat each Input) async throws -> Output {
        try invoke(repeat each input).get()
    }
}

