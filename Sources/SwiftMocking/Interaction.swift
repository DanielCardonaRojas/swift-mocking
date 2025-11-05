//
//  Interaction.swift
//  Mockable
//
//  Created by Daniel Cardona on 6/07/25.
//

/// Represents a specific interaction with a mock object, combining an ``InvocationMatcher`` and a ``Spy``.
///
/// This struct is primarily used internally by the Mockable framework and in conjunction with the ``when(_:)`` and ``verify(_:)`` functions
/// to define stubbing behavior or verify method calls.
///
/// ## Usage
/// Interactions are typically created by generated mock methods and used with:
/// - ``when(_:)`` - For stubbing method behavior
/// - ``verify(_:)`` - For verifying method calls
/// - ``verifyNever(_:)`` - For ensuring methods were not called
///
/// ## Related Types
/// - ``Spy`` - The spy that records invocations for this interaction
/// - ``InvocationMatcher`` - Matches method arguments
/// - ``Stub`` - Defines return behavior for matched interactions
public struct Interaction<each Input, Eff: Effect, Output> {
    /// The matcher that defines the arguments for this interaction.
    public let invocationMatcher: InvocationMatcher<repeat each Input>
    /// The spy associated with this interaction.
    public let spy: Spy<repeat each Input, Eff, Output>

    /// Initializes an `Interaction` instance.
    /// - Parameters:
    ///   - matchers: A variadic list of ``ArgMatcher``s, one for each input parameter of the method.
    ///   - spy: The ``Spy`` instance that this interaction is associated with.
    public init(_ matchers: repeat ArgMatcher<each Input>, spy: Spy<repeat each Input, Eff, Output>) {
        self.invocationMatcher = InvocationMatcher(matchers: repeat each matchers)
        self.spy = spy
    }

    init(invocationMatcher: InvocationMatcher<repeat each Input>, spy: Spy<repeat each Input, Eff, Output>) {
        self.invocationMatcher = invocationMatcher
        self.spy = spy
    }

    public func invocations() -> [(repeat each Input)]{
        var arguments = [(repeat each Input)]()
        for invocation in spy.invocations {
            if invocationMatcher.isMatchedBy(invocation) {
                arguments.append(invocation.arguments)
            }
        }
        return arguments
    }
}

// MARK: - Stubbing Convenience Methods
// These extensions provide convenience methods on Interaction for use within when { } blocks

// MARK: - None
public extension Interaction where Eff == None {
    @discardableResult
    func thenReturn(_ output: Output) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        let stub = spy.makeStub(for: invocationMatcher)
        stub.thenReturn(output)
        return ConfiguredInteraction(interaction: self, stub: stub)
    }

    @discardableResult
    func thenReturn(_ handler: @escaping (repeat each Input) -> Output) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        let stub = spy.makeStub(for: invocationMatcher)
        stub.thenReturn(handler)
        return ConfiguredInteraction(interaction: self, stub: stub)
    }

    @discardableResult
    func `do`(_ handler: @escaping (repeat each Input) -> Void) -> Interaction<repeat each Input, Eff, Output> {
        let action = Action<repeat each Input, Eff>(invocationMatcher: invocationMatcher)
        action.do(handler)
        spy.registerAction(action)
        return self
    }
}

// MARK: - Throws
public extension Interaction where Eff == Throws {
    @discardableResult
    func thenReturn(_ output: Output) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        let stub = spy.makeStub(for: invocationMatcher)
        stub.thenReturn(output)
        return ConfiguredInteraction(interaction: self, stub: stub)
    }

    @discardableResult
    func thenThrow<E: Error>(_ error: E) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        let stub = spy.makeStub(for: invocationMatcher)
        stub.thenThrow(error)
        return ConfiguredInteraction(interaction: self, stub: stub)
    }

    @discardableResult
    func thenReturn(_ handler: @escaping (repeat each Input) throws -> Output) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        let stub = spy.makeStub(for: invocationMatcher)
        stub.thenReturn(handler)
        return ConfiguredInteraction(interaction: self, stub: stub)
    }

    @discardableResult
    func `do`(_ handler: @escaping (repeat each Input) throws -> Void) -> Interaction<repeat each Input, Eff, Output> {
        let action = Action<repeat each Input, Eff>(invocationMatcher: invocationMatcher)
        action.do(handler)
        spy.registerAction(action)
        return self
    }
}

// MARK: - Async
public extension Interaction where Eff == Async {
    @discardableResult
    func thenReturn(_ output: Output) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        let stub = spy.makeStub(for: invocationMatcher)
        stub.thenReturn(output)
        return ConfiguredInteraction(interaction: self, stub: stub)
    }

    @discardableResult
    func thenReturn(_ handler: @escaping (repeat each Input) async -> Output) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        let stub = spy.makeStub(for: invocationMatcher)
        stub.thenReturn(handler)
        return ConfiguredInteraction(interaction: self, stub: stub)
    }

    @discardableResult
    func `do`(_ handler: @escaping (repeat each Input) async -> Void) -> Interaction<repeat each Input, Eff, Output> {
        let action = Action<repeat each Input, Eff>(invocationMatcher: invocationMatcher)
        action.do(handler)
        spy.registerAction(action)
        return self
    }
}

// MARK: - AsyncThrows
public extension Interaction where Eff == AsyncThrows {
    @discardableResult
    func thenReturn(_ output: Output) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        let stub = spy.makeStub(for: invocationMatcher)
        stub.thenReturn(output)
        return ConfiguredInteraction(interaction: self, stub: stub)
    }

    @discardableResult
    func thenThrow<E: Error>(_ error: E) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        let stub = spy.makeStub(for: invocationMatcher)
        stub.thenThrow(error)
        return ConfiguredInteraction(interaction: self, stub: stub)
    }

    @discardableResult
    func thenReturn(_ handler: @escaping (repeat each Input) async throws -> Output) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        let stub = spy.makeStub(for: invocationMatcher)
        stub.thenReturn(handler)
        return ConfiguredInteraction(interaction: self, stub: stub)
    }

    @discardableResult
    func `do`(_ handler: @escaping (repeat each Input) async throws -> Void) -> Interaction<repeat each Input, Eff, Output> {
        let action = Action<repeat each Input, Eff>(invocationMatcher: invocationMatcher)
        action.do(handler)
        spy.registerAction(action)
        return self
    }
}

// MARK: - Void convenience aliases
public extension Interaction where Output == Void, Eff == None {
    @discardableResult
    func then(_ handler: @escaping (repeat each Input) -> Void) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        thenReturn(handler)
    }
}

public extension Interaction where Output == Void, Eff == Throws {
    @discardableResult
    func then(_ handler: @escaping (repeat each Input) throws -> Void) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        thenReturn(handler)
    }
}

public extension Interaction where Output == Void, Eff == Async {
    @discardableResult
    func then(_ handler: @escaping (repeat each Input) async -> Void) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        thenReturn(handler)
    }
}

public extension Interaction where Output == Void, Eff == AsyncThrows {
    @discardableResult
    func then(_ handler: @escaping (repeat each Input) async throws -> Void) -> ConfiguredInteraction<repeat each Input, Eff, Output> {
        thenReturn(handler)
    }
}
