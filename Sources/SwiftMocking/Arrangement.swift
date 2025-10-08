//
//  Arrangement.swift
//  SwiftMocking
//
//  Created by Daniel Cardona on 7/03/25.
//

/// Facade that exposes both stubbing and action registration for a matched interaction.
public final class Arrangement<each I, Eff: Effect, Output> {
    private let interaction: Interaction<repeat each I, Eff, Output>
    private var storedStub: Stub<repeat each I, Eff, Output>?

    init(interaction: Interaction<repeat each I, Eff, Output>) {
        self.interaction = interaction
    }

    public var invocationMatcher: InvocationMatcher<repeat each I> {
        interaction.invocationMatcher
    }

    private func ensureStub() -> Stub<repeat each I, Eff, Output> {
        if let storedStub {
            return storedStub
        }
        let stub = interaction.spy.createStub(for: interaction.invocationMatcher)
        storedStub = stub
        return stub
    }

    fileprivate func registerAction(_ configure: (Action<repeat each I, Eff>) -> Void) -> Action<repeat each I, Eff> {
        interaction.spy.registerAction(for: invocationMatcher, configure: configure)
    }
}

// MARK: - None
public extension Arrangement where Eff == None {
    func thenReturn(_ output: Output) {
        ensureStub().thenReturn(output)
    }

    func thenReturn(_ handler: @escaping (repeat each I) -> Output) {
        ensureStub().thenReturn(handler)
    }

    @discardableResult
    func `do`(_ handler: @escaping (repeat each I) -> Void) -> Action<repeat each I, Eff> {
        registerAction { action in
            action.`do`(handler)
        }
    }
}

// MARK: - Throws
public extension Arrangement where Eff == Throws {
    func thenReturn(_ output: Output) {
        ensureStub().thenReturn(output)
    }

    func thenReturn(_ handler: @escaping (repeat each I) -> Output) {
        ensureStub().thenReturn(handler)
    }

    func thenThrow<E: Error>(_ error: E) {
        ensureStub().thenThrow(error)
    }

    func thenReturn(_ handler: @escaping (repeat each I) throws -> Output) {
        ensureStub().thenReturn(handler)
    }

    @discardableResult
    func `do`(_ handler: @escaping (repeat each I) throws -> Void) -> Action<repeat each I, Eff> {
        registerAction { action in
            action.`do`(handler)
        }
    }
}

// MARK: - Async
public extension Arrangement where Eff == Async {
    func thenReturn(_ output: Output) {
        ensureStub().thenReturn(output)
    }

    func thenReturn(_ handler: @escaping (repeat each I) -> Output) {
        ensureStub().thenReturn(handler)
    }

    func thenReturn(_ handler: @escaping (repeat each I) async -> Output) {
        ensureStub().thenReturn(handler)
    }

    @discardableResult
    func `do`(_ handler: @escaping (repeat each I) async -> Void) -> Action<repeat each I, Eff> {
        registerAction { action in
            action.`do`(handler)
        }
    }
}

// MARK: - AsyncThrows
public extension Arrangement where Eff == AsyncThrows {
    func thenReturn(_ output: Output) {
        ensureStub().thenReturn(output)
    }

    func thenReturn(_ handler: @escaping (repeat each I) -> Output) {
        ensureStub().thenReturn(handler)
    }

    func thenThrow<E: Error>(_ error: E) {
        ensureStub().thenThrow(error)
    }

    func thenReturn(_ handler: @escaping (repeat each I) async -> Output) {
        ensureStub().thenReturn(handler)
    }

    func thenReturn(_ handler: @escaping (repeat each I) async throws -> Output) {
        ensureStub().thenReturn(handler)
    }

    @discardableResult
    func `do`(_ handler: @escaping (repeat each I) async throws -> Void) -> Action<repeat each I, Eff> {
        registerAction { action in
            action.`do`(handler)
        }
    }
}

// MARK: - Void convenience aliases
public extension Arrangement where Output == Void, Eff == None {
    func then(_ handler: @escaping (repeat each I) -> Void) {
        thenReturn(handler)
    }
}

public extension Arrangement where Output == Void, Eff == Throws {
    func then(_ handler: @escaping (repeat each I) -> Void) {
        thenReturn(handler)
    }

    func then(_ handler: @escaping (repeat each I) throws -> Void) {
        thenReturn(handler)
    }
}

public extension Arrangement where Output == Void, Eff == Async {
    func then(_ handler: @escaping (repeat each I) -> Void) {
        thenReturn(handler)
    }

    func then(_ handler: @escaping (repeat each I) async -> Void) {
        thenReturn(handler)
    }
}

public extension Arrangement where Output == Void, Eff == AsyncThrows {
    func then(_ handler: @escaping (repeat each I) -> Void) {
        thenReturn(handler)
    }

    func then(_ handler: @escaping (repeat each I) async -> Void) {
        thenReturn(handler)
    }

    func then(_ handler: @escaping (repeat each I) throws -> Void) {
        thenReturn(handler)
    }

    func then(_ handler: @escaping (repeat each I) async throws -> Void) {
        thenReturn(handler)
    }
}
