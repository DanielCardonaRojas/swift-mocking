//
//  Arrangement.swift
//  SwiftMocking
//
//  Created by Daniel Cardona on 7/03/25.
//

/// Facade that exposes both stubbing and action registration for a matched interaction.
public final class Arrange<each I, Eff: Effect, Output> {
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
    func thenReturn(_ output: Output) {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenReturn(output)
    }

    func thenReturn(_ handler: @escaping (repeat each I) -> Output) {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenReturn(handler)
    }

    func `do`(_ handler: @escaping (repeat each I) -> Void) {
        let action = Action<repeat each I, Eff>(invocationMatcher: interaction.invocationMatcher)
        action.do(handler)
        interaction.spy.registerAction(action)
    }
}

// MARK: - Throws
public extension Arrange where Eff == Throws {
    func thenReturn(_ output: Output) {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenReturn(output)
    }

    func thenThrow<E: Error>(_ error: E) {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenThrow(error)
    }

    func thenReturn(_ handler: @escaping (repeat each I) throws -> Output) {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenReturn(handler)
    }

    func `do`(_ handler: @escaping (repeat each I) throws -> Void) {
        let action = Action<repeat each I, Eff>(invocationMatcher: interaction.invocationMatcher)
        action.do(handler)
        interaction.spy.registerAction(action)
    }
}

// MARK: - Async
public extension Arrange where Eff == Async {
    func thenReturn(_ output: Output) {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenReturn(output)
    }

    func thenReturn(_ handler: @escaping (repeat each I) async -> Output) {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenReturn(handler)
    }

    func `do`(_ handler: @escaping (repeat each I) async -> Void) {
        let action = Action<repeat each I, Eff>(invocationMatcher: interaction.invocationMatcher)
        action.do(handler)
        interaction.spy.registerAction(action)
    }
}

// MARK: - AsyncThrows
public extension Arrange where Eff == AsyncThrows {
    func thenReturn(_ output: Output) {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenReturn(output)
    }

    func thenThrow<E: Error>(_ error: E) {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenThrow(error)
    }

    func thenReturn(_ handler: @escaping (repeat each I) async throws -> Output) {
        interaction.spy.createStub(for: interaction.invocationMatcher).thenReturn(handler)
    }

    func `do`(_ handler: @escaping (repeat each I) async throws -> Void) {
        let action = Action<repeat each I, Eff>(invocationMatcher: interaction.invocationMatcher)
        action.do(handler)
        interaction.spy.registerAction(action)
    }
}

// MARK: - Void convenience aliases
public extension Arrange where Output == Void, Eff == None {
    func then(_ handler: @escaping (repeat each I) -> Void) {
        thenReturn(handler)
    }
}

public extension Arrange where Output == Void, Eff == Throws {
    func then(_ handler: @escaping (repeat each I) throws -> Void) {
        thenReturn(handler)
    }
}

public extension Arrange where Output == Void, Eff == Async {
    func then(_ handler: @escaping (repeat each I) async -> Void) {
        thenReturn(handler)
    }
}

public extension Arrange where Output == Void, Eff == AsyncThrows {
    func then(_ handler: @escaping (repeat each I) async throws -> Void) {
        thenReturn(handler)
    }
}
