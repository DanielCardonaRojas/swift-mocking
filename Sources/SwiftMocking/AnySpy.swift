//
//  AnySpy.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 8/10/25.
//

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
/// The `Sendable` requirement is unconditional even though ``Spy``'s own conformance is
/// conditional, so erasing a spy over non-`Sendable` types to `any AnySpy` yields a
/// `Sendable` value. That is sound rather than a loophole: every member below traffics
/// only in `Sendable` types, and each is backed by the same lock-guarded storage, so no
/// non-`Sendable` value is reachable through this interface. Keep it that way — adding a
/// member that exposes a spy's `Input` or `Output` would break the guarantee.
/// The action machinery of a spy, erased over its `Output`.
///
/// ``Spy`` is only `Sendable` when both its inputs *and* its output are, because it
/// stores stubbed outputs. Registering an action touches none of that — it is pure
/// bookkeeping over the invocation matcher — so waiting for a call should not require a
/// `Sendable` return type.
///
/// This protocol exposes exactly that bookkeeping. Its members traffic only in an opaque
/// action token and a label — never in an `Input` or `Output` *value* — so ``Spy``
/// conforms unconditionally, and `until(_:timeout:)` can capture a `Sendable` handle to a
/// spy that is not itself `Sendable`.
///
/// The conformance has to be unconditional: `Sendable` is a marker protocol, and a
/// conditional conformance to a non-marker protocol cannot depend on one.
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

public protocol AnySpy: AnyObject, Sendable {
    /// The registry used to provide default values for unstubbed method calls.
    var defaultProviderRegistry: DefaultProvidableRegistry? { get set }

    /// The total number of times this spy has been invoked.
    var invocationCount: Int { get }

    /// Whether logging is enabled for this spy's invocations.
    var isLoggingEnabled: Bool { get set }

    /// Clears all recorded invocations and stubs from this spy.
    func clear()
}

