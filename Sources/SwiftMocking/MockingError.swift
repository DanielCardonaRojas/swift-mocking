//
//  MockingError.swift
//  Mockable
//
//  Created by Daniel Cardona on 4/07/25.
//

/// Represents an error that occurred during mocking or verification.
public struct MockingError: Error, Equatable, Sendable {
    public static func == (lhs: MockingError, rhs: MockingError) -> Bool {
        return lhs.message == rhs.message
    }

    /// A descriptive message about the error.
    public let message: String

    /// Indicates that a method was called on a spy but no corresponding stub was found.
    public static func unStubbed(_ name: String? = nil, inputs: String? = nil) -> MockingError {
        let message = [
            "Unstubbed method",
            name.map { "\"\($0).\""},
            inputs.map { "No configured return value for inputs: \($0)" }
        ].compactMap { $0 }.joined(separator: " ")
        return MockingError(message: message)
    }

    /// Indicates that a method was expected to throw an error, but it did not.
    public static let didNotThrow = MockingError(message: "Did not find any invocation that throws")

    /// Indicates that a method was expected to throw an error, but it did not.
    /// - Parameter method: The label of the method that was verified.
    public static func didNotThrow(_ method: String?) -> MockingError {
        MockingError(
            message: describe("Did not find any invocation that throws", method: method)
        )
    }

    /// Indicates that a method threw an error, but it did not match the expected error.
    /// - Parameter thrown: An array of errors that were actually thrown.
    public static func didNotMatchThrown(_ thrown: [any Error]) -> MockingError {
        return MockingError(message: "Did not match any thrown error. Thrown: \(thrown)")
    }

    /// Indicates that a method threw an error, but it did not match the expected error.
    /// - Parameters:
    ///   - thrown: The errors that were actually thrown.
    ///   - method: The label of the method that was verified.
    public static func didNotMatchThrown(_ thrown: [any Error], method: String?) -> MockingError {
        // `String(reflecting:)` keeps the module qualification (`MyTests.AnotherError()`),
        // which distinguishes same-named error types declared in different modules.
        let list = thrown.map { String(reflecting: $0) }.joined(separator: ", ")
        return MockingError(
            message: describe("Did not match any thrown error. Thrown: [\(list)]", method: method)
        )
    }

    /// Indicates that the actual call count of a method did not match the expected call count.
    /// - Parameter actual: The actual number of times the method was called.
    public static func unfulfilledCallCount(_ actual: Int) -> MockingError {
        MockingError(message: "Unfulfilled call count. Actual: \(actual)")
    }

    /// Indicates that the actual call count of a method did not match the expected call count.
    ///
    /// Includes the method label, what was expected, and the invocations that *were*
    /// recorded, so the failure can be diagnosed without re-reading the test.
    /// - Parameters:
    ///   - actual: The actual number of times the method was called.
    ///   - expected: A description of the expected count, e.g. `equal to 2`.
    ///   - method: The label of the method that was verified.
    ///   - recorded: Descriptions of the invocations recorded on the spy.
    public static func unfulfilledCallCount(
        _ actual: Int,
        expected: String?,
        method: String?,
        recorded: [String]
    ) -> MockingError {
        var message = describe("Unfulfilled call count", method: method)
        if let expected {
            message += " Expected \(expected), but was called \(actual) time(s)."
        } else {
            message += " Actual: \(actual)."
        }
        message += recordedSuffix(recorded)
        return MockingError(message: message)
    }

    /// Indicates that no matching invocations were found for captured() inspection.
    public static let noMatchingInvocations = MockingError(message: "No matching invocations found for captured() inspection")

    /// Indicates that no matching invocations were found for captured() inspection.
    /// - Parameters:
    ///   - method: The label of the method that was inspected.
    ///   - recorded: Descriptions of the invocations recorded on the spy.
    public static func noMatchingInvocations(method: String?, recorded: [String]) -> MockingError {
        let message = describe(
            "No matching invocations found for captured() inspection",
            method: method
        ) + recordedSuffix(recorded)
        return MockingError(message: message)
    }

    /// Terminates a message with the method label, when one is known.
    ///
    /// Always ends the clause with a period so callers can append further sentences
    /// without producing run-on text, whether or not a label was available.
    private static func describe(_ message: String, method: String?) -> String {
        guard let method else { return "\(message)." }
        return "\(message) for \"\(method)\"."
    }

    /// Renders the recorded invocations, or an explicit note that there were none.
    ///
    /// Distinguishing "never called" from "called with other arguments" is usually the
    /// fastest route to the cause of a verification failure.
    private static func recordedSuffix(_ recorded: [String]) -> String {
        guard !recorded.isEmpty else {
            return "\nNo invocations were recorded."
        }
        let list = recorded.map { "  - \($0)" }.joined(separator: "\n")
        return "\nRecorded invocations:\n\(list)"
    }
}

/// An error thrown when `until` fails to observe a matching interaction before timing out.
///
/// `until` throws rather than reporting an issue directly: callers must already `try await`
/// it, so the test framework attributes the failure to that `try` in the user's test. The
/// associated values exist so the thrown error says *what* timed out — a bare `.timeout`
/// gives no indication of which interaction was being awaited.
public enum UntilError: Error, Sendable, CustomStringConvertible {
    /// The awaited interaction was not observed before the timeout elapsed.
    ///
    /// The associated values are optional so existing `case .timeout` patterns keep
    /// compiling and matching.
    case timeout(method: String? = nil, duration: Duration? = nil)

    public var description: String {
        switch self {
        case let .timeout(method, duration):
            let subject = method.map { "\"\($0)\"" } ?? "interaction"
            guard let duration else {
                return "Timed out waiting for \(subject) to be called."
            }
            return "Timed out after \(duration) waiting for \(subject) to be called."
        }
    }
}
