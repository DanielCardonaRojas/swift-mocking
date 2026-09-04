//
//  Effects.swift
//  Mockable
//
//  Created by Daniel Cardona on 6/07/25.
//


/// A protocol that defines the effect of a method, such as throwing an error or being asynchronous.
///
/// This protocol is used internally by the Mockable framework to generate appropriate mock implementations.
public protocol Effect: Sendable { }

/// Represents a method that can throw an error.
public enum Throws: Effect, Sendable { }

/// Represents a method that can throw exactly one concrete error type.
///
/// This is the typed-throws counterpart of ``Throws``, carrying the declared error
/// type as a phantom parameter so it survives into the spy's type. A requirement
/// `func load() throws(LoadError) -> Data` produces a
/// `Spy<Void, TypedThrows<LoadError>, Data>`, and the generated conformance rethrows
/// as `throws(LoadError)` — the error type is checked at compile time rather than
/// erased to `any Error`.
///
/// Stubbing is constrained to match: `thenThrow` on such a spy only accepts a
/// `LoadError`, so a mismatched error is a compile error instead of a test that
/// fails at runtime.
public enum TypedThrows<E: Error>: Effect, Sendable { }

/// An effect that names the single concrete error type its method can throw.
///
/// Conformance projects that error type out of the phantom effect as ``Failure``, so
/// generic code constrains on the effect (`where Effects: TypedThrowingEffect`) and
/// still refers to the concrete error as `Effects.Failure`. Writing the constraint as
/// `Effects == TypedThrows<E>` on each extension would work too, but `some Error` is
/// not permitted in an extension's `where` clause, and an associated type keeps the
/// synchronous and asynchronous cases sharing one constraint shape.
public protocol TypedThrowingEffect: Effect {
    /// The concrete error type methods with this effect are declared to throw.
    associatedtype Failure: Error
}

/// A synchronous typed-throwing effect.
///
/// Extensions constrain on this rather than on `Effects == TypedThrows<E>` because
/// `some Error` is not permitted in an extension's `where` clause. A marker protocol
/// separates the synchronous and asynchronous cases — which need different call
/// signatures — while both keep projecting ``TypedThrowingEffect/Failure``.
public protocol SyncTypedThrowingEffect: TypedThrowingEffect { }

/// An asynchronous typed-throwing effect. See ``SyncTypedThrowingEffect``.
public protocol AsyncTypedThrowingEffect: TypedThrowingEffect { }

extension TypedThrows: SyncTypedThrowingEffect {
    public typealias Failure = E
}

/// Represents an asynchronous method.
public enum Async: Effect, Sendable { }

/// Represents a method that can also throw an error.
public enum AsyncThrows: Effect, Sendable { }

/// Represents an asynchronous method that can throw exactly one concrete error type.
///
/// The `async` counterpart of ``TypedThrows`` — see that type for how the declared
/// error type is carried and enforced.
public enum AsyncTypedThrows<E: Error>: Effect, Sendable { }

extension AsyncTypedThrows: AsyncTypedThrowingEffect {
    public typealias Failure = E
}

/// Represents a method that has no special effects (neither throws nor is asynchronous).
public enum None: Effect, Sendable { }
