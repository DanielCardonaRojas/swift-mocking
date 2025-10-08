//
//  Action.swift
//  SwiftMocking
//
//  Created by Daniel Cardona on 7/03/25.
//

/// Represents a side-effect associated with an invocation matcher.
///
/// Actions are executed when an invocation matches their matcher, allowing
/// callers to run custom closures without influencing the stubbed return value.
public class Action<each I, Eff: Effect> {
    public let invocationMatcher: InvocationMatcher<repeat each I>
    var handler: ((Invocation<repeat each I>) -> Return<Eff, Void>)?

    init(invocationMatcher: InvocationMatcher<repeat each I>) {
        self.invocationMatcher = invocationMatcher
    }

    @discardableResult
    func perform(for invocation: Invocation<repeat each I>) -> Return<Eff, Void>? {
        handler?(invocation)
    }

    public var precedence: MatcherPrecedence {
        .init(value: invocationMatcher.precedence)
    }
}

extension Action where Eff == None {
    /// Registers a synchronous action.
    public func `do`(_ handler: @escaping (repeat each I) -> Void) {
        self.handler = { invocation in
            Return<None, Void> {
                .success(handler(repeat each invocation.arguments))
            }
        }
    }
}

extension Action where Eff == Throws {
    /// Registers a throwing synchronous action.
    public func `do`(_ handler: @escaping (repeat each I) throws -> Void) {
        self.handler = { invocation in
            Return<Throws, Void> {
                Result {
                    try handler(repeat each invocation.arguments)
                }
            }
        }
    }
}

extension Action where Eff == Async {
    /// Registers an asynchronous action.
    public func `do`(_ handler: @escaping (repeat each I) async -> Void) {
        self.handler = { invocation in
            Return<Async, Void> {
                await handler(repeat each invocation.arguments)
                return .success(())
            }
        }
    }
}

extension Action where Eff == AsyncThrows {
    /// Registers an asynchronous throwing action.
    public func `do`(_ handler: @escaping (repeat each I) async throws -> Void) {
        self.handler = { invocation in
            Return<AsyncThrows, Void> {
                do {
                    try await handler(repeat each invocation.arguments)
                    return .success(())
                } catch {
                    return .failure(error)
                }
            }
        }
    }
}
