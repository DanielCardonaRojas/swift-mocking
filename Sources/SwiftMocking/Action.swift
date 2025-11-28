//
//  Action.swift
//  SwiftMocking
//
//  Created by Daniel Cardona on 7/03/25.
//

/// Represents a side-effect associated with an invocation matcher.
///
/// Actions are executed whenever an invocation matches their matcher, allowing
/// callers to run custom closures without influencing the stubbed return value.
public final class Action<each I, Eff: Effect>: @unchecked Sendable {
    public let invocationMatcher: InvocationMatcher<repeat each I>

    fileprivate var syncPerformer: ((Invocation<repeat each I>) -> Void)?
    fileprivate var throwingPerformer: ((Invocation<repeat each I>) throws -> Void)?
    fileprivate var asyncPerformer: ((Invocation<repeat each I>) async -> Void)?
    fileprivate var asyncThrowingPerformer: ((Invocation<repeat each I>) async throws -> Void)?

    init(invocationMatcher: InvocationMatcher<repeat each I>) {
        self.invocationMatcher = invocationMatcher
    }

    public var precedence: MatcherPrecedence {
        .init(value: invocationMatcher.precedence)
    }
}

extension Action where Eff == None {
    /// Registers a synchronous action.
    public func `do`(_ handler: @escaping (repeat each I) -> Void) {
        syncPerformer = { invocation in
            handler(repeat each invocation.arguments)
        }
    }

    @usableFromInline
    func perform(_ invocation: Invocation<repeat each I>) {
        syncPerformer?(invocation)
    }
}

extension Action where Eff == Throws {
    /// Registers a throwing synchronous action.
    public func `do`(_ handler: @escaping (repeat each I) throws -> Void) {
        throwingPerformer = { invocation in
            try handler(repeat each invocation.arguments)
        }
    }

    @usableFromInline
    func perform(_ invocation: Invocation<repeat each I>) throws {
        try throwingPerformer?(invocation)
    }
}

extension Action where Eff == Async {
    /// Registers an asynchronous action.
    public func `do`(_ handler: @escaping (repeat each I) async -> Void) {
        asyncPerformer = { invocation in
            await handler(repeat each invocation.arguments)
        }
    }

    @usableFromInline
    func perform(_ invocation: Invocation<repeat each I>) async {
        await asyncPerformer?(invocation)
    }
}

extension Action where Eff == AsyncThrows {
    /// Registers an asynchronous throwing action.
    public func `do`(_ handler: @escaping (repeat each I) async throws -> Void) {
        asyncThrowingPerformer = { invocation in
            try await handler(repeat each invocation.arguments)
        }
    }

    @usableFromInline
    func perform(_ invocation: Invocation<repeat each I>) async throws {
        try await asyncThrowingPerformer?(invocation)
    }
}
