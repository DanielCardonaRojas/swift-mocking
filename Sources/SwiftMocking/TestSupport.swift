//
//  XCTestCase+Extensions.swift
//  Mockable
//
//  Created by Daniel Cardona on 6/07/25.
//

import Foundation
import IssueReporting

// MARK: Mockito utilities

/// Configures a stub for a mock object.
///
/// Use this function to define the behavior of a mocked method when it is called.
/// It takes an `Interaction` object, which represents a specific method call
/// on a mock, and returns a `Stub` object that allows you to chain further
/// configurations like `thenReturn`, `thenThrow`, or `thenDoNothing`.
///
/// Example:
/// ```swift
/// when(mock.someMethod(param1: .any, param2: .equal(5)))
///     .thenReturn("mocked_value")
/// ```
///
/// - Parameter interaction: An `Interaction` object representing the method call to stub.
/// - Returns: An `Arrange` object to configure the mock's behavior and side effects.
public func when<each Input, Eff: Effect, Output>(_ interaction: Interaction<repeat each Input, Eff, Output>) -> Arrange<repeat each Input, Eff, Output> {
    interaction.spy.when(calledWith: interaction.invocationMatcher)
}

/// Verifies that a specific interaction with a mock object has occurred.
///
/// This function is used to assert that a mocked method was called with arguments
/// matching the provided `Interaction`.
/// It returns an `Assert` object, which allows you to specify the expected
/// number of calls using `.called()` or to assert that it threw an error using `.throws()`.
/// Note that async-throwing interactions require awaiting the `.throws()` assertion (e.g. `await verify(mock.load()).throws()`).
///
/// Example:
/// ```swift
/// verify(mock.someMethod(param1: .any, param2: .equal(5)))
///     .called(1)
/// ```
///
/// - Parameter interaction: An `Interaction` object representing the method call to verify.
/// - Returns: An `Assert` object to specify verification criteria.
public func verify<each Input, Eff: Effect, Output>(
    _ interaction: Interaction<repeat each Input, Eff, Output>
) -> Assert<repeat each Input, Eff, Output>  {
    Assert(invocationMatcher: interaction.invocationMatcher, spy: interaction.spy)
}

/// Verifies that a sequence of interactions across multiple mock objects occurred in the specified order.
///
/// This function enables cross-spy call order verification, allowing you to verify that method calls
/// across different mock objects occurred in a specific chronological order.
///
/// Example:
/// ```swift
/// verifyInOrder([
///     mock1.firstMethod(),
///     mock2.secondMethod(arg: 1),
///     mock1.thirdMethod()
/// ])
/// ```
///
/// - Parameters:
///   - verifiables: An array of `CrossSpyVerifiable` objects representing the expected sequence of calls.
public func verifyInOrder(
    _ verifiables: [any CrossSpyVerifiable],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let result = CrossSpyVerification.verifyInOrder(verifiables)
    if let result {
        let matchedSequenceDescription = result.matched.map({ recorded in
            let method = "\(recorded.methodLabel)"
            let arguments = recorded.arguments.map({ "\($0)"}).joined(
                separator: ", "
            )
            return "\(method)(\(arguments))"
        }).joined(separator: "\n")

        if result.matched.isEmpty {
            reportIssue("Did not find sequence of interactions", filePath: file, line: line)
        } else {
            reportIssue(
                "Partially found sequence of interactions. Matched \(result.matched.count) of \(result.matched.count + result.expectedRemaining) expected. Matched up to:\n\(matchedSequenceDescription)",
                filePath: file,
                line: line
            )
        }
    }
}

/// Verifies that a specific interaction with a mock object never occurred.
///
/// This function is a convenience wrapper that asserts a mocked method was never called
/// with arguments matching the provided `Interaction`. It's equivalent to calling
/// `verify(interaction).neverCalled()` but provides a more direct API.
///
/// Example:
/// ```swift
/// verifyNever(mock.someMethod(param1: .any))
/// verifyNever(mock.sensitiveMethod(password: .equal("secret")))
/// ```
///
/// - Parameter interaction: An `Interaction` object representing the method call that should never have occurred.
public func verifyNever<each Input, Eff: Effect, Output>(
    _ interaction: Interaction<repeat each Input, Eff, Output>,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    verify(interaction).neverCalled(file: file, line: line)
}

/// Verifies that a mock object has had zero interactions.
///
/// This function asserts that none of the methods on the given mock have been called.
/// It checks all spies managed by the mock to ensure they have zero invocations.
/// This is useful when you want to ensure a mock object was completely unused.
///
/// Example:
/// ```swift
/// let mock = MockPricingService()
/// let anotherMock = MockNetworkService()
/// 
/// // ... test logic that should not interact with these mocks ...
/// 
/// verifyZeroInteractions(mock)
/// verifyZeroInteractions(anotherMock)
/// ```
///
/// - Parameter mock: A `Mock` object to verify has had no interactions.
public func verifyZeroInteractions(
    _ mock: Mock,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let totalInvocations = mock.spies.values.flatMap { $0 }.reduce(0) { $0 + $1.invocationCount }
    
    if totalInvocations > 0 {
        let mockTypeName = String(describing: type(of: mock))
        reportIssue("Expected zero interactions with \(mockTypeName) but found \(totalInvocations) invocation(s)", filePath: file, line: line)
    }
}

// MARK: - Await utilities

private final class FulfillmentTracker {
    private var fulfilled = false
    private let lock = NSLock()

    func tryFulfill() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !fulfilled else { return false }
        fulfilled = true
        return true
    }
}

public func until<each Input, Output>(
    _ interaction: Interaction<repeat each Input, None, Output>,
    timeout: Duration = .seconds(1)
) async throws {
    try await withUntilTimeout(interaction: interaction, timeout: timeout) { action, tracker, cleanup in
        action.do { (_: repeat each Input) in
            if tracker.tryFulfill() {
                cleanup()
            }
        }
    }
}

/// Waits until the provided async interaction has been recorded using action hooks.
public func until<each Input, Output>(
    _ interaction: Interaction<repeat each Input, Async, Output>,
    timeout: Duration = .seconds(1)
) async throws {
    try await withUntilTimeout(interaction: interaction, timeout: timeout) { action, tracker, cleanup in
        action.do { (_: repeat each Input) async in
            if tracker.tryFulfill() {
                cleanup()
            }
        }
    }
}

/// Waits until the provided async throwing interaction has been recorded using action hooks.
public func until<each Input, Output>(
    _ interaction: Interaction<repeat each Input, AsyncThrows, Output>,
    timeout: Duration = .seconds(1)
) async throws {
    try await withUntilTimeout(interaction: interaction, timeout: timeout) { action, tracker, cleanup in
        action.do { (_: repeat each Input) async throws in
            if tracker.tryFulfill() {
                cleanup()
            }
        }
    }
}

// MARK: Asserts

public extension Assert {
    /// Asserts that the mocked method was called a specific number of times.
    ///
    /// - Parameter countMatcher: An `ArgMatcher<Int>` to specify the expected call count.
    ///   Defaults to `.equal(1)` if `nil`, meaning the method is expected to be called exactly once.
    func called(
        _ countMatcher: ArgMatcher<Int>? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            try self.assert(countMatcher)
        } catch let error as MockingError {
            reportIssue("\(error.message)", filePath: file, line: line)
        } catch {
            reportIssue("\(error.localizedDescription)", filePath: file, line: line)
        }
    }

}

public extension Assert {
    /// Inspects captured arguments with automatic error reporting
    func captured(
        _ inspector: @escaping (repeat each Input) throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            try self.captures(inspector)
        } catch let error as MockingError {
            reportIssue("\(error.message)", filePath: file, line: line)
        } catch {
            reportIssue("\(error.localizedDescription)", filePath: file, line: line)
        }
    }
}

public extension Assert where Eff == Throws {
    /// Asserts that the mocked method threw an error.
    ///
    /// - Parameter errorMatcher: An `ArgMatcher<any Error>` to specify the expected error.
    ///   Defaults to `.anyError()` if `nil`, meaning any error is expected.
    func `throws`(
        _ errorMatcher: ArgMatcher<any Error>? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            try doesThrow(errorMatcher)
        } catch let error as MockingError {
            reportIssue("\(error.message)", filePath: file, line: line)
        } catch {
            reportIssue("\(error.localizedDescription)", filePath: file, line: line)
        }
    }
}

public extension Assert where Eff == AsyncThrows {
    /// Asserts asynchronously that the mocked method threw an error.
    ///
    /// - Parameter errorMatcher: An `ArgMatcher<any Error>` to specify the expected error.
    ///   Defaults to `.anyError()` if `nil`, meaning any error is expected.
    func `throws`(
        _ errorMatcher: ArgMatcher<any Error>? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await doesThrow(errorMatcher)
        } catch let error as MockingError {
            reportIssue("\(error.message)", filePath: file, line: line)
        } catch {
            reportIssue("\(error.localizedDescription)", filePath: file, line: line)
        }
    }
}

private func withUntilTimeout<each Input, Eff: Effect>(
    interaction: Interaction<repeat each Input, Eff, some Any>,
    timeout: Duration,
    actionHandler: @escaping (Action<repeat each Input, Eff>, FulfillmentTracker, @escaping () -> Void) -> Void
) async throws {
    let tracker = FulfillmentTracker()
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        var actionReference: Action<repeat each Input, Eff>?
        let timer = Task {
            try await Task.sleep(for: timeout)
            if tracker.tryFulfill() {
                if let actionReference {
                    interaction.spy.removeAction(actionReference)
                }
                continuation.resume(throwing: UntilError.timeout)
            }
        }

        let cleanup = {
            timer.cancel()
            if let actionReference {
                interaction.spy.removeAction(actionReference)
            }
            continuation.resume()
        }

        let action = Action<repeat each Input, Eff>(invocationMatcher: interaction.invocationMatcher)
        actionHandler(action, tracker, cleanup)

        actionReference = action
        interaction.spy.registerAction(action)
    }
}

