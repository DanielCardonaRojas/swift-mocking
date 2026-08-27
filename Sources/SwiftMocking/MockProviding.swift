//
//  MockProviding.swift
//  swift-mocking
//

/// A type that exposes the ``Mock`` backing its spies.
///
/// Generated mocks reach spy storage in one of two ways:
///
/// - By **inheriting** ``Mock`` — the default strategy, where `super.name`
///   resolves the spy.
/// - By **holding** one — the `@Mockable([.composition])` strategy, where
///   `mock.name` resolves the spy. Required when the mock must inherit some
///   other superclass, as it must for a protocol carrying a class constraint
///   (`protocol Service: SomeBaseClass`).
///
/// Most of the API is unaffected by the difference, because ``Interaction``
/// carries a ``Spy`` and never knows which type declared it. This protocol
/// exists for the APIs that need the mock's *whole* spy set rather than one
/// named requirement — ``verifyZeroInteractions(_:fileID:file:line:column:)`` —
/// so they accept both strategies.
///
/// ``Mock`` conforms by returning itself, so inheriting mocks satisfy the
/// requirement without generating anything.
public protocol MockProviding {
    /// The mock holding this type's spies.
    var mock: Mock { get }
}

extension Mock: MockProviding {
    /// An inheriting mock *is* its own spy storage.
    public var mock: Mock { self }
}

public extension MockProviding {
    /// Clears all recorded invocations and stubs from this mock's spies.
    ///
    /// A composing type does not inherit ``Mock/clear()``, so without this it
    /// would have to reach through its storage — `mock.mock.clear()`. Inheriting
    /// mocks are unaffected: they get ``Mock/clear()`` directly, and it takes
    /// precedence over this extension.
    func clear() {
        mock.clear()
    }

}

/// A type that exposes the ``Mock`` backing its **static** spies.
///
/// Static requirements cannot reach an instance property, so a mock generated
/// with `@Mockable([.composition])` keeps a second `Mock` for them. This
/// protocol exposes it, mirroring ``MockProviding`` for the static half.
///
/// Only mocks that actually have static requirements conform — the generator
/// emits the storage, and this conformance, only then.
public protocol StaticMockProviding {
    /// The mock holding this type's static spies.
    static var staticMock: Mock { get }
}

public extension StaticMockProviding {
    /// Clears all recorded invocations and stubs from this type's static spies.
    ///
    /// Static spies live in ``MockScope``'s scoped storage under the mock's own
    /// type name — the same place and identity an inheriting mock's static
    /// spies use — so this clears exactly this mock's static spies and leaves
    /// other mocks untouched.
    static func clear() {
        staticMock.clear()
    }
}
