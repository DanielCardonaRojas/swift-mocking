//
//  Arrangement.swift
//  SwiftMocking
//
//  Created by Daniel Cardona on 7/03/25.
//

/// A protocol that marks types used for stub configuration.
///
/// Types conforming to this protocol can be collected in `whenAll` blocks
/// for ergonomic stub setup in AAA (Arrange-Act-Assert) test patterns.
public protocol StubbingConfiguration {}

/// Facade that exposes both stubbing and action registration for a matched interaction.
public final class Arrange<each I, Eff: Effect, Output>: StubbingConfiguration {
    private let interaction: Interaction<repeat each I, Eff, Output>

    init(interaction: Interaction<repeat each I, Eff, Output>) {
        self.interaction = interaction
    }

    public var invocationMatcher: InvocationMatcher<repeat each I> {
        interaction.invocationMatcher
    }
}

// MARK: - None
public extension Arrange where Eff == None {
    @discardableResult
    func thenReturn(_ output: Output) -> Self {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenReturn(output)
        return self
    }

    @discardableResult
    func thenReturn(_ handler: @escaping (repeat each I) -> Output) -> Self {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenReturn(handler)
        return self
    }

    @discardableResult
    func `do`(_ handler: @escaping (repeat each I) -> Void) -> Self {
        let action = Action<repeat each I, Eff>(invocationMatcher: interaction.invocationMatcher)
        action.do(handler)
        interaction.spy.registerAction(action)
        return self
    }
}

// MARK: - Throws
public extension Arrange where Eff == Throws {
    @discardableResult
    func thenReturn(_ output: Output) -> Self {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenReturn(output)
        return self
    }

    @discardableResult
    func thenThrow<E: Error>(_ error: E) -> Self {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenThrow(error)
        return self
    }

    @discardableResult
    func thenReturn(_ handler: @escaping (repeat each I) throws -> Output) -> Self {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenReturn(handler)
        return self
    }

    @discardableResult
    func `do`(_ handler: @escaping (repeat each I) throws -> Void) -> Self {
        let action = Action<repeat each I, Eff>(invocationMatcher: interaction.invocationMatcher)
        action.do(handler)
        interaction.spy.registerAction(action)
        return self
    }
}

// MARK: - Async
public extension Arrange where Eff == Async {
    @discardableResult
    func thenReturn(_ output: Output) -> Self {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenReturn(output)
        return self
    }

    @discardableResult
    func thenReturn(_ handler: @escaping (repeat each I) async -> Output) -> Self {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenReturn(handler)
        return self
    }

    @discardableResult
    func `do`(_ handler: @escaping (repeat each I) async -> Void) -> Self {
        let action = Action<repeat each I, Eff>(invocationMatcher: interaction.invocationMatcher)
        action.do(handler)
        interaction.spy.registerAction(action)
        return self
    }
}

// MARK: - AsyncThrows
public extension Arrange where Eff == AsyncThrows {
    @discardableResult
    func thenReturn(_ output: Output) -> Self {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenReturn(output)
        return self
    }

    @discardableResult
    func thenThrow<E: Error>(_ error: E) -> Self {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenThrow(error)
        return self
    }

    @discardableResult
    func thenReturn(_ handler: @escaping (repeat each I) async throws -> Output) -> Self {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenReturn(handler)
        return self
    }

    @discardableResult
    func `do`(_ handler: @escaping (repeat each I) async throws -> Void) -> Self {
        let action = Action<repeat each I, Eff>(invocationMatcher: interaction.invocationMatcher)
        action.do(handler)
        interaction.spy.registerAction(action)
        return self
    }
}

// MARK: - Void convenience aliases
public extension Arrange where Output == Void, Eff == None {
    @discardableResult
    func then(_ handler: @escaping (repeat each I) -> Void) -> Self {
        thenReturn(handler)
    }
}

public extension Arrange where Output == Void, Eff == Throws {
    @discardableResult
    func then(_ handler: @escaping (repeat each I) throws -> Void) -> Self {
        thenReturn(handler)
    }
}

public extension Arrange where Output == Void, Eff == Async {
    @discardableResult
    func then(_ handler: @escaping (repeat each I) async -> Void) -> Self {
        thenReturn(handler)
    }
}

public extension Arrange where Output == Void, Eff == AsyncThrows {
    @discardableResult
    func then(_ handler: @escaping (repeat each I) async throws -> Void) -> Self {
        thenReturn(handler)
    }
}

