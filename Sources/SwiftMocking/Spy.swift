//
//  Spy.swift
//  Witness
//
//  Created by Daniel Cardona on 3/07/25.
//
import Foundation

/// A ``Spy`` is a type that captures calls to a single method, enabling inspections.
///
/// You can use a ``Spy`` to verify that a method was called with specific arguments, or to check how many times it was called.
/// Spies are useful for testing interactions between objects.
///
/// You don't create spies manually. Instead, you use the ``Mockable`` macro to generate a spy for a protocol, or a ``Mock`` to create them
/// through dynamic member lookup subscripts.
///
/// ## Related Types
/// - ``Mock`` - Base class that manages and provides access to spies
/// - ``Stub`` - Defines behavior for method calls
/// - ``Interaction`` - Represents a method call for verification
/// - ``ArgMatcher`` - Matches method arguments with various criteria
public class Spy<each Input, Effects: Effect, Output>: AnySpy {
    /// A publicly accessible array of all ``Invocation``s captured by this spy.
    public private(set) var invocations: [Invocation<repeat each Input>] = []
    public var isLoggingEnabled: Bool = false
    private let invocationsLock = NSLock()
    private let stubsLock = NSLock()
    private let actionsLock = NSLock()

    private(set) var stubs: [Stub<repeat each Input, Effects, Output>] = []
    private(set) var actions: [Action<repeat each Input, Effects>] = []
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
    func invoke(_ input: repeat each Input) throws -> Return<Effects, Output> {
        invocationsLock.lock()
        defer { invocationsLock.unlock() }
        let invocation = Invocation(arguments: repeat each input)
        invocations.append(invocation)

        // Log invocations
        if isLoggingEnabled {
            logger?(invocation)
        }

        // search through stub for a return value

        var matchingStub = matchingStub(invocation: invocation)
        guard let returnValue = matchingStub?.returnValue(for: invocation) else {
            if let fallback = defaultProviderRegistry?.getDefaultForType(Output.self) {
                return .value(fallback)
            }

            throw MockingError.unStubbed
        }

        return returnValue
    }

    private func matchingStub(invocation: Invocation<repeat each Input>) -> Stub<repeat each Input, Effects, Output>? {
        var matchingStub: Stub<repeat each Input, Effects, Output>?
        for stub in stubs.reversed().sorted(by: { $0.precedence > $1.precedence }) {
            if stub.invocationMatcher.isMatchedBy(invocation) {
                matchingStub = stub
                break
            }
        }
        return matchingStub
    }

    private func matchingAction(invocation: Invocation<repeat each Input>) -> Action<repeat each Input, Effects>? {
        for action in actions .reversed() .sorted(by: { $0.precedence > $1.precedence }) {
            if action.invocationMatcher.isMatchedBy(invocation) {
                return action
            }
        }
        return nil
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
        stubsLock.lock()
        defer { stubsLock.unlock() }
        let stub = Stub<repeat each Input, Effects, Output>(invocationMatcher: invocationMatcher)
        stubs.append(stub)
        return stub
    }

    @discardableResult
    func registerAction(
        for invocationMatcher: InvocationMatcher<repeat each Input>,
        configure: (Action<repeat each Input, Effects>) -> Void
    ) -> Action<repeat each Input, Effects> {
        let action = Action<repeat each Input, Effects>(invocationMatcher: invocationMatcher)
        configure(action)
        actionsLock.lock()
        actions.append(action)
        actionsLock.unlock()
        return action
    }

    /// Available so that spies can be used with `when` and `verify`.
    public func callAsFunction(_ matchingInput: repeat ArgMatcher<each Input>) -> Interaction<repeat each Input, Effects, Output> {
        Interaction(repeat each matchingInput, spy: self)
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

    /// Clear stubs and invocations,  leaving the spy in a fresh state.
    public func clear() {
        stubs = []
        actions = []
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

    public func asFunction() -> (repeat each Input) throws -> Output {
        return { (args:  repeat each Input) in
            try self.call(repeat each args)
        }
    }

    /// Verifies that the spy's method threw an error matching the given `errorMatcher`.
    /// - Parameter errorMatcher: An ``ArgMatcher`` for `Error` to specify the expected error.
    /// - Returns: `true` if a matching error was thrown, `false` otherwise.
    public func verifyThrows(_ errorMatcher: ArgMatcher<any Error>) -> Bool {
        var doesThrow = false
        for invocation in invocations {
            for stub in stubs where stub.invocationMatcher.isMatchedBy(invocation) {
                guard let stubbedReturn = stub.returnValue(for: invocation) else {
                    continue
                }
                switch stubbedReturn.resolve() {
                case .success:
                    break
                case .failure(let error):
                    doesThrow = errorMatcher(error)
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
            let returnValue = try invoke(repeat each input)
            return returnValue.get()
        } catch let error as MockingError {
            fatalError("MockingError: \(error.message)")
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }

    public func asFunction() -> (repeat each Input) -> Output {
        return { (args:  repeat each Input) in
            self.call(repeat each args)
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
            let returnValue = try invoke(repeat each input)
            return await returnValue.get()
        } catch let error as MockingError {
            fatalError("MockingError: \(error.message)")
        } catch {
            fatalError("\(error.localizedDescription)")
        }
    }

    public func asFunction() -> (repeat each Input) async -> Output {
        return { (args:  repeat each Input) in
            await self.call(repeat each args)
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
        let returnValue = try invoke(repeat each input)
        return try await returnValue.get()
    }

    public func asFunction() -> (repeat each Input) async throws -> Output {
        return { (args:  repeat each Input) in
            try await self.call(repeat each args)
        }
    }

    /// Verifies that the spy's method threw an error matching the given `errorMatcher`.
    /// - Parameter errorMatcher: An ``ArgMatcher`` for `Error` to specify the expected error.
    /// - Returns: `true` if a matching error was thrown, `false` otherwise.
    public func verifyThrows(_ errorMatcher: ArgMatcher<any Error>) async -> Bool {
        var doesThrow = false
        for invocation in invocations {
            for stub in stubs where stub.invocationMatcher.isMatchedBy(invocation) {
                guard let stubbedReturn = stub.returnValue(for: invocation) else {
                    continue
                }
                let resolved = await stubbedReturn.resolveAsync()
                switch resolved {
                case .success:
                    break
                case .failure(let error):
                    doesThrow = errorMatcher(error)
                }
            }
        }
        return doesThrow
    }

    /// Verifies that the spy's method threw any error.
    /// - Returns: `true` if any error was thrown, `false` otherwise.
    public func verifyThrows() async -> Bool {
        await verifyThrows(.anyError())
    }
}
