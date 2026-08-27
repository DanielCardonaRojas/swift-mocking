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
