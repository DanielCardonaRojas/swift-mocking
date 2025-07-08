//
//  Invocation.swift
//  Mockable
//
//  Created by Daniel Cardona on 8/07/25.
//

/// Represents a captured invocation of a function for later inspection.
///
/// An `Invocation` is a container for the arguments passed to a function during a specific call.
/// It is used by the mocking framework to record interactions with mock objects.
///
/// Example:
/// ```swift
/// let invocation = Invocation(arguments: 1, "test")
/// print(invocation.arguments) // prints "(1, "test")"
/// ```
public struct Invocation<each Input> {
    /// The arguments passed to the function.
    public let arguments: (repeat each Input)

    init(arguments: repeat each Input) {
        self.arguments = (repeat each arguments)
    }
}

