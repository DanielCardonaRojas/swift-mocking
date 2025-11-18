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
        var argStrings = [String]()
        for argument in repeat each arguments {
            argStrings.append("\(argument)")
        }
        let formattedDescription = "(" + argStrings.joined(separator: ", ") + ")"
        return formattedDescription

    }

    /// The arguments passed to the function.
    public let arguments: (repeat each Input)

    /// Initializes an `Invocation` instance with the given arguments.
    /// - Parameter arguments: The arguments captured during a function call.
    init(arguments: repeat each Input) {
        self.arguments = (repeat each arguments)
    }
}

extension Invocation: Sendable where repeat each Input: Sendable { }

