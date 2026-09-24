//
//  AnySpy.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 8/10/25.
//

/// The action machinery of a spy, erased over its `Output`.
///
/// ``Spy`` is only `Sendable` when both its inputs *and* its output are, because it
/// stores stubbed outputs. Registering an action touches none of that — it is pure
/// bookkeeping over the invocation matcher — so waiting for a call should not require a
/// `Sendable` return type.
///
/// This protocol exposes exactly that bookkeeping. Its members traffic only in an opaque
/// action token and a label — never in an `Input` or `Output` *value* — so
/// `until(_:timeout:)` can capture a `Sendable` handle to a spy that is not itself
/// `Sendable`.
///
/// ``Spy`` does not conform directly; ``Spy/actionRegistrar`` vends a small non-generic
/// class that does. Conforming `Spy` itself would require it to be *unconditionally*
/// `Sendable` at this package's Swift 6.0 floor, which is exactly the conditional
/// conformance this indirection exists to preserve.
///
/// - Important: Every member must stay free of `Input` and `Output` values. Adding one
///   that exposes either would make the conformance unsound.
public protocol SpyActionRegistering: AnyObject, Sendable {
    /// Human-readable label for the spy, used in timeout diagnostics.
    var actionMethodLabel: String? { get }

    /// Registers a previously created action to run on matching invocations.
    ///
    /// The action is passed as `AnyObject` so this protocol need not name the spy's
    /// input pack. Implementations cast back to their own action type and ignore
    /// anything else, which is safe because the only caller hands back the token it
    /// received from the same spy.
    func registerErasedAction(_ action: AnyObject)

    /// Removes a previously registered action.
    func removeErasedAction(_ action: AnyObject)
}

/// A type-erased protocol that defines the common interface for all spy objects.
///
/// This protocol provides a unified interface for managing spy objects regardless
/// of their specific type parameters. It allows the `Mock` class to store and
/// manage spies with different signatures in a collection.
///
/// The protocol defines essential properties and methods that all spies must support:
/// - Tracking the number of invocations
/// - Managing logging configuration
/// - Providing default value registries
/// - Clearing recorded state
///
/// Deliberately does *not* inherit `Sendable`, even though every member traffics only in
/// `Sendable` types over lock-guarded storage. On Swift 6.0 — this package's toolchain
/// floor — a type cannot conform to a `Sendable`-inheriting protocol unless it is
/// unconditionally `Sendable`, so inheriting it here would force ``Spy`` to choose between
/// its conditional conformance and conforming at all. Swift 6.1 relaxed that rule, but the
/// floor is what has to compile.
///
/// The cost is that `any AnySpy` is not `Sendable`, so containers of erased spies need a
/// box that does not require it; see ``SpyStorageProvider``. Sharing an erased spy remains
/// safe for the reason above — this is a compiler-expressiveness limit, not a soundness
/// one. Keep it that way: a member exposing a spy's `Input` or `Output` would make erased
/// sharing genuinely unsafe.
public protocol AnySpy: AnyObject {
    /// The registry used to provide default values for unstubbed method calls.
    var defaultProviderRegistry: DefaultProvidableRegistry? { get set }

    /// The total number of times this spy has been invoked.
    var invocationCount: Int { get }

    /// Whether logging is enabled for this spy's invocations.
    var isLoggingEnabled: Bool { get set }

    /// Clears all recorded invocations and stubs from this spy.
    func clear()
}

