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
///
/// An action is registered on a ``Spy`` before its performer is installed, so a
/// concurrent invocation can read the performer while it is being written. Each is
/// held in a ``LockIsolated`` box, and `perform` reads the closure out before calling
/// it so user code never runs under the lock.
public final class Action<each I, Eff: Effect> {
    public let invocationMatcher: InvocationMatcher<repeat each I>

    fileprivate let syncPerformer = LockIsolated<(@Sendable (Invocation<repeat each I>) -> Void)?>(nil)
    fileprivate let throwingPerformer = LockIsolated<(@Sendable (Invocation<repeat each I>) throws -> Void)?>(nil)
    fileprivate let asyncPerformer = LockIsolated<(@Sendable (Invocation<repeat each I>) async -> Void)?>(nil)
    fileprivate let asyncThrowingPerformer = LockIsolated<(@Sendable (Invocation<repeat each I>) async throws -> Void)?>(nil)

    init(invocationMatcher: InvocationMatcher<repeat each I>) {
        self.invocationMatcher = invocationMatcher
    }

    public var precedence: MatcherPrecedence {
        .init(value: invocationMatcher.precedence)
    }
}

extension Action: Sendable where repeat each I: Sendable { }

extension Action where Eff == None {
    /// Registers a synchronous action.
    public func `do`(_ handler: @escaping @Sendable (repeat each I) -> Void) {
        syncPerformer.withLock { performer in
            performer = { invocation in
                handler(repeat each invocation.arguments)
            }
        }
    }

    @usableFromInline
    func perform(_ invocation: Invocation<repeat each I>) {
        let performer = syncPerformer.withLock { $0 }
        performer?(invocation)
    }
}

extension Action where Eff == Throws {
    /// Registers a throwing synchronous action.
    public func `do`(_ handler: @escaping @Sendable (repeat each I) throws -> Void) {
        throwingPerformer.withLock { performer in
            performer = { invocation in
                try handler(repeat each invocation.arguments)
            }
        }
    }

    @usableFromInline
    func perform(_ invocation: Invocation<repeat each I>) throws {
        let performer = throwingPerformer.withLock { $0 }
        try performer?(invocation)
    }
}

extension Action where Eff: SyncTypedThrowingEffect {
    /// Registers a throwing synchronous action.
    ///
    /// The handler is constrained to the effect's declared error type, so an action
    /// cannot introduce an error the requirement is not allowed to throw.
    public func `do`(_ handler: @escaping @Sendable (repeat each I) throws(Eff.Failure) -> Void) {
        throwingPerformer.withLock { performer in
            performer = { invocation in
                try handler(repeat each invocation.arguments)
            }
        }
    }

    @usableFromInline
    func perform(_ invocation: Invocation<repeat each I>) throws {
        let performer = throwingPerformer.withLock { $0 }
        try performer?(invocation)
    }
}

extension Action where Eff: AsyncTypedThrowingEffect {
    /// Registers an asynchronous throwing action.
    ///
    /// See the synchronous overload for why the handler's error type is constrained.
    public func `do`(_ handler: @escaping @Sendable (repeat each I) async throws(Eff.Failure) -> Void) {
        asyncThrowingPerformer.withLock { performer in
            performer = { invocation in
                try await handler(repeat each invocation.arguments)
            }
        }
    }

    @usableFromInline
    func perform(_ invocation: Invocation<repeat each I>) async throws {
        let performer = asyncThrowingPerformer.withLock { $0 }
        try await performer?(invocation)
    }
}

extension Action where Eff == Async {
    /// Registers an asynchronous action.
    public func `do`(_ handler: @escaping @Sendable (repeat each I) async -> Void) {
        asyncPerformer.withLock { performer in
            performer = { invocation in
                await handler(repeat each invocation.arguments)
            }
        }
    }

    @usableFromInline
    func perform(_ invocation: Invocation<repeat each I>) async {
        let performer = asyncPerformer.withLock { $0 }
        await performer?(invocation)
    }
}

extension Action where Eff == AsyncThrows {
    /// Registers an asynchronous throwing action.
    public func `do`(_ handler: @escaping @Sendable (repeat each I) async throws -> Void) {
        asyncThrowingPerformer.withLock { performer in
            performer = { invocation in
                try await handler(repeat each invocation.arguments)
            }
        }
    }

    @usableFromInline
    func perform(_ invocation: Invocation<repeat each I>) async throws {
        let performer = asyncThrowingPerformer.withLock { $0 }
        try await performer?(invocation)
    }
}
