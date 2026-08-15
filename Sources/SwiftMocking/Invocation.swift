//
//  Invocation.swift
//  Mockable
//
//  Created by Daniel Cardona on 8/07/25.
//

import Foundation

/// Represents a captured invocation of a function for later inspection.
///
/// An `Invocation` is a container for the arguments passed to a function during a specific call.
/// It is used by the mocking framework to record interactions with mock objects.
///
/// ### Usage Example:
///
/// ```swift
/// let invocation = Invocation(arguments: 1, "test")
/// print(invocation.arguments) // prints "(1, "test")"
/// ```
public struct Invocation<each Input>: CustomDebugStringConvertible {
    /// Unique identifier for this specific invocation
    public let invocationID: UUID = UUID()
    public var debugDescription: String {
        // Swift 5.9-compatible pack bridge (for-in over packs requires Swift 6).
        let argStrings = anyList(repeat each arguments).map { "\($0)" }
        return "(" + argStrings.joined(separator: ", ") + ")"
    }

    /// The arguments passed to the function.
    public let arguments: (repeat each Input)

    /// Initializes an `Invocation` instance with the given arguments.
    /// - Parameter arguments: The arguments captured during a function call.
    @usableFromInline
    init(arguments: repeat each Input) {
        self.arguments = (repeat each arguments)
    }
}

extension Invocation: Sendable where repeat each Input: Sendable { }

