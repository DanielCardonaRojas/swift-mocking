//
//  SettableInteraction.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 20/08/25.
//

import Foundation

/// A read/write interaction surface for a settable requirement.
///
/// Settable members record reads and writes on two distinct spies — their input
/// packs differ (`(indices…)` for reads, `(indices…, newValue)` for writes) — so
/// a single ``Interaction`` cannot address both. Generated mocks for settable
/// requirements return this wrapper instead, carrying both bindings:
/// ``get`` addresses reads, and ``set(_:)`` addresses writes.
///
/// `Input` is the read pack: the index pack for a subscript requirement, or
/// `(Void)` for a variable requirement. `Output` is the element type. The write
/// pack is always the read pack plus the written value.
///
/// ## Usage
/// ```swift
/// when(mock[.any]).thenReturn("stubbed")             // stub reads
/// verify(mock[.equal(1)], assigned: "one").called(1) // verify writes
/// verify(mock.value, assigned: 7).called(1)          // variables likewise
/// verifyInOrder([mock[.any].set(.equal("one"))])     // composes via set(_:)
/// ```
///
/// Get-only requirements keep returning ``Interaction`` directly, so passing
/// `assigned:` for them is a compile-time error.
///
/// ## Related Types
/// - ``Interaction`` - the single-direction surface this type wraps
/// - ``Spy`` - records invocations for each direction
public struct SettableInteraction<each Input, Output> {
    /// The read interaction — records on the requirement's getter spy.
    public let get: Interaction<repeat each Input, None, Output>

    /// Builds the write interaction for a matched value.
    ///
    /// Injected by generated code because appending a value after a pack
    /// expansion (`(repeat each Input, Output)`) is not expressible in a
    /// generic body on this toolchain.
    private let setInteraction: @Sendable (ArgMatcher<Output>) -> Interaction<repeat each Input, Output, None, Void>

    /// Initializes a `SettableInteraction` with both directions' bindings.
    ///
    /// - Parameters:
    ///   - get: The interaction for reads.
    ///   - setInteraction: Builds the write interaction for an assigned-value
    ///     matcher; the generated implementation records on the write spy with
    ///     the read matchers followed by the value matcher.
    public init(
        get: Interaction<repeat each Input, None, Output>,
        setInteraction: @escaping @Sendable (ArgMatcher<Output>) -> Interaction<repeat each Input, Output, None, Void>
    ) {
        self.get = get
        self.setInteraction = setInteraction
    }

    /// Returns the write interaction for a matched value.
    ///
    /// The result is a plain ``Interaction`` recording on the write spy with
    /// the read pack's matchers followed by `newValue`, so it composes with
    /// `verifyInOrder`, `captured`, and `until` unchanged.
    ///
    /// - Parameter newValue: Matcher for the assigned value.
    /// - Returns: The write interaction.
    public func set(_ newValue: ArgMatcher<Output>) -> Interaction<repeat each Input, Output, None, Void> {
        setInteraction(newValue)
    }
}

extension SettableInteraction: Sendable where repeat each Input: Sendable, Output: Sendable { }
