//
//  MockingError.swift
//  Mockable
//
//  Created by Daniel Cardona on 4/07/25.
//

/// Represents an error that occurred during mocking or verification.
public struct MockingError: Error, Equatable {
    public static func == (lhs: MockingError, rhs: MockingError) -> Bool {
        return lhs.message == rhs.message
    }

    /// A descriptive message about the error.
    public let message: String

    /// Indicates that a method was called on a spy but no corresponding stub was found.
    public static let unStubbed = MockingError(message: "Unstubbed method")

    /// Indicates that a method was expected to throw an error, but it did not.
    public static let didNotThrow = MockingError(message: "Did not find any invocation that throws")

    /// Indicates that a method threw an error, but it did not match the expected error.
    /// - Parameter thrown: An array of errors that were actually thrown.
    public static func didNotMatchThrown(_ thrown: [any Error]) -> MockingError {
        return MockingError(message: "Did not match any thrown error. Thrown: \(thrown)")
    }

    /// Indicates that the actual call count of a method did not match the expected call count.
    /// - Parameter actual: The actual number of times the method was called.
    public static func unfulfilledCallCount(_ actual: Int) -> MockingError {
        MockingError(message: "Unfulfilled call count. Actual: \(actual)")
    }

    /// Indicates that no matching invocations were found for captured() inspection.
    public static let noMatchingInvocations = MockingError(message: "No matching invocations found for captured() inspection")
}
