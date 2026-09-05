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

///
/// This overload accepts an unapplied reference to a parameterless interaction member —
/// most notably a mocked variable's getter interaction — so stubbing reads like a plain
/// property read:
/// ```swift
/// when(mock.name).thenReturn("mocked_value")
/// ```
public func when<each Input, Eff: Effect, Output>(_ interaction: (()) -> Interaction<repeat each Input, Eff, Output>) -> Arrange<repeat each Input, Eff, Output> {
    let interaction = interaction(())
    return interaction.spy.when(calledWith: interaction.invocationMatcher)
}

/// Configures a stub for the reads of a settable requirement.
///
/// ```swift
/// when(mock[.any]).thenReturn("mocked_value")
/// ```
public func when<each Input, Eff: Effect, Output>(
    _ interaction: SettableInteraction<repeat each Input, Eff, Output>
) -> Arrange<repeat each Input, Eff, Output> {
    when(interaction.get)
}

/// Configures a stub for the reads of a settable variable, accepting an
/// unapplied reference to its interaction member:
/// ```swift
/// when(mock.value).thenReturn("mocked_value")
/// ```
public func when<each Input, Eff: Effect, Output>(
    _ interaction: (()) -> SettableInteraction<repeat each Input, Eff, Output>
) -> Arrange<repeat each Input, Eff, Output> {
    when(interaction(()).get)
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

/// Verifies that a specific interaction with a mock object has occurred, accepting an
/// unapplied reference to a parameterless interaction member (e.g. a mocked variable's
/// getter interaction) so verification reads like a plain property read:
/// ```swift
/// verify(mock.name).called(1)
/// ```
public func verify<each Input, Eff: Effect, Output>(
    _ interaction: (()) -> Interaction<repeat each Input, Eff, Output>
) -> Assert<repeat each Input, Eff, Output> {
    let interaction = interaction(())
    return Assert(invocationMatcher: interaction.invocationMatcher, spy: interaction.spy)
}

/// Verifies the reads of a settable requirement.
public func verify<each Input, Eff: Effect, Output>(
    _ interaction: SettableInteraction<repeat each Input, Eff, Output>
) -> Assert<repeat each Input, Eff, Output> {
    verify(interaction.get)
}

/// Verifies the reads of a settable variable, accepting an unapplied
/// reference to its interaction member: `verify(mock.value).called(1)`.
public func verify<each Input, Eff: Effect, Output>(
    _ interaction: (()) -> SettableInteraction<repeat each Input, Eff, Output>
) -> Assert<repeat each Input, Eff, Output> {
    verify(interaction(()).get)
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
///   - file: The file where a verification failure is reported.
///   - line: The line where a verification failure is reported.
public func verifyInOrder(
    _ verifiables: [any CrossSpyVerifiable],
    fileID: StaticString = #fileID,
    file: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) {
    let location = SourceLocation(fileID: fileID, filePath: file, line: line, column: column)
    let result = CrossSpyVerification.verifyInOrder(verifiables)
    if let result {
        let matchedSequenceDescription = result.matched.map({ recorded in
            let method = "\(recorded.methodLabel ?? "unknownMethodLabel")"
            let arguments = recorded.arguments.map({ "\($0)"}).joined(
                separator: ", "
            )
            return "\(method)(\(arguments))"
        }).joined(separator: "\n")

        if result.matched.isEmpty {
            location.report("Did not find sequence of interactions")
        } else {
            location.report(
                "Partially found sequence of interactions. Matched \(result.matched.count) of \(result.matched.count + result.expectedRemaining) expected. Matched up to:\n\(matchedSequenceDescription)"
            )
        }
    }
}

public func verifyInOrder(
    @CrossSpyVerificationBuilder _ builder: () -> [any CrossSpyVerifiable],
    fileID: StaticString = #fileID,
    file: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) {
    verifyInOrder(builder(), fileID: fileID, file: file, line: line, column: column)
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
/// - Parameter file: The file where a verification failure is reported.
/// - Parameter line: The line where a verification failure is reported.
public func verifyNever<each Input, Eff: Effect, Output>(
    _ interaction: Interaction<repeat each Input, Eff, Output>,
    fileID: StaticString = #fileID,
    file: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) {
    verify(interaction).neverCalled(fileID: fileID, file: file, line: line, column: column)
}

/// Verifies that a specific interaction with a mock object never occurred, accepting an
/// unapplied reference to a parameterless interaction member (e.g. a mocked variable's
/// getter interaction): `verifyNever(mock.name)`.
public func verifyNever<each Input, Eff: Effect, Output>(
    _ interaction: (()) -> Interaction<repeat each Input, Eff, Output>,
    fileID: StaticString = #fileID,
    file: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) {
    verify(interaction).neverCalled(fileID: fileID, file: file, line: line, column: column)
}

/// Verifies that a settable requirement was never read.
public func verifyNever<each Input, Eff: Effect, Output>(
    _ interaction: SettableInteraction<repeat each Input, Eff, Output>,
    fileID: StaticString = #fileID,
    file: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) {
    verify(interaction.get).neverCalled(fileID: fileID, file: file, line: line, column: column)
}

/// Verifies that a settable variable was never read, accepting an unapplied
/// reference to its interaction member: `verifyNever(mock.value)`.
public func verifyNever<each Input, Eff: Effect, Output>(
    _ interaction: (()) -> SettableInteraction<repeat each Input, Eff, Output>,
    fileID: StaticString = #fileID,
    file: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) {
    verify(interaction(()).get).neverCalled(fileID: fileID, file: file, line: line, column: column)
}

infix operator <- : AssignmentPrecedence


/// Builds the write interaction for a settable requirement.
///
/// The result is a plain ``Interaction``, so `when`, `verify`, `verifyNever`,
/// and `verifyInOrder` consume writes through their existing overloads:
/// ```swift
/// verify(mock[.equal(2)] <- "two").called(1)
/// when(mock.value <- 7).thenReturn { _, newValue in … }
/// verifyNever(mock[.any] <- "deleted")
/// ```
///
/// The result is deliberately not `@discardableResult`: this operator only
/// *builds* an interaction, it records nothing. A bare `mock.value <- 7`
/// statement looks like it performs a write but is a no-op, so the unused-result
/// warning is what surfaces that mistake. To perform an actual write, assign to
/// the requirement (`mock.value = 7`).
public func <- <each Input, Eff: Effect, Output>(
    _ interaction: SettableInteraction<repeat each Input, Eff, Output>,
    _ newValue: ArgMatcher<Output>
) -> Interaction<repeat each Input, Output, None, Void> {
    interaction.set(newValue)
}

/// Builds the write interaction for a settable variable, accepting an
/// unapplied reference to its interaction member: `mock.value <- 7`.
///
/// Not `@discardableResult`, for the reason given on the overload above.
public func <- <each Input, Eff: Effect, Output>(
    _ interaction: (()) -> SettableInteraction<repeat each Input, Eff, Output>,
    _ newValue: ArgMatcher<Output>
) -> Interaction<repeat each Input, Output, None, Void> {
    interaction(()).set(newValue)
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
/// Accepts both generation strategies through ``MockProviding``: a mock that
/// inherits ``Mock`` provides itself, and one generated with
/// `@Mockable([.composition])` provides the ``Mock`` it holds.
///
/// - Parameter mock: A mock to verify has had no interactions.
/// - Parameter file: The file where a verification failure is reported.
/// - Parameter line: The line where a verification failure is reported.
public func verifyZeroInteractions(
    _ mock: some MockProviding,
    fileID: StaticString = #fileID,
    file: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) {
    let storage = mock.mock
    let totalInvocations = storage.spies.values.flatMap { $0 }.reduce(0) { $0 + $1.invocationCount }

    if totalInvocations > 0 {
        // The composing type, not the `Mock` it holds — `MockService` reads
        // better in a failure than the bare `Mock` every composed mock shares.
        let mockTypeName = String(describing: type(of: mock))
        let location = SourceLocation(fileID: fileID, filePath: file, line: line, column: column)
        location.report("Expected zero interactions with \(mockTypeName) but found \(totalInvocations) invocation(s)")
    }
}

// MARK: - Await utilities

private final class FulfillmentTracker: @unchecked Sendable {
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
) async throws where repeat each Input: Sendable
{
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
) async throws where repeat each Input: Sendable
{
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
) async throws where repeat each Input: Sendable
{
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
    /// Asserts that the mocked method was called a number of times matching `countMatcher`.
    ///
    /// Passing a bare `Int` asserts an exact count, since `ArgMatcher` conforms to
    /// `ExpressibleByIntegerLiteral`:
    ///
    /// ```swift
    /// verify(mock.price(for: .any)).called()               // at least once
    /// verify(mock.price(for: .any)).called(2)              // exactly twice
    /// verify(mock.price(for: .any)).called(.greaterThan(1))
    /// verify(mock.price(for: .any)).called(.in(1...3))
    /// verify(mock.price(for: "cherry")).called(.equal(0))  // see also `neverCalled()`
    /// ```
    ///
    /// - Parameter countMatcher: An `ArgMatcher<Int>` to specify the expected call count.
    ///   Defaults to `.greaterThan(.zero)` if `nil`, meaning the method is expected to be
    ///   called *at least once*. Pass `.equal(1)` to require exactly one call.
    /// - Parameter file: The file where a verification failure is reported.
    /// - Parameter line: The line where a verification failure is reported.
    func called(
        _ countMatcher: ArgMatcher<Int>? = nil,
        fileID: StaticString = #fileID,
        file: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) {
        do {
            try self.assert(countMatcher)
        } catch {
            SourceLocation(fileID: fileID, filePath: file, line: line, column: column).report(error)
        }
    }

}

public extension Assert {
    /// Inspects captured arguments with automatic error reporting
    func captured(
        _ inspector: @escaping (repeat each Input) throws -> Void,
        fileID: StaticString = #fileID,
        file: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) {
        do {
            try self.captures(inspector)
        } catch {
            SourceLocation(fileID: fileID, filePath: file, line: line, column: column).report(error)
        }
    }
}

public extension Assert where Eff == Throws {
    /// Asserts that the mocked method threw an error.
    ///
    /// - Parameter errorMatcher: An `ArgMatcher<any Error>` to specify the expected error.
    ///   Defaults to `.anyError()` if `nil`, meaning any error is expected.
    /// - Parameter file: The file where a verification failure is reported.
    /// - Parameter line: The line where a verification failure is reported.
    func `throws`(
        _ errorMatcher: ArgMatcher<any Error>? = nil,
        fileID: StaticString = #fileID,
        file: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) {
        do {
            try doesThrow(errorMatcher)
        } catch {
            SourceLocation(fileID: fileID, filePath: file, line: line, column: column).report(error)
        }
    }
}

public extension Assert where Eff == AsyncThrows {
    /// Asserts asynchronously that the mocked method threw an error.
    ///
    /// - Parameter errorMatcher: An `ArgMatcher<any Error>` to specify the expected error.
    ///   Defaults to `.anyError()` if `nil`, meaning any error is expected.
    /// - Parameter file: The file where a verification failure is reported.
    /// - Parameter line: The line where a verification failure is reported.
    func `throws`(
        _ errorMatcher: ArgMatcher<any Error>? = nil,
        fileID: StaticString = #fileID,
        file: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) async {
        do {
            try await doesThrow(errorMatcher)
        } catch {
            SourceLocation(fileID: fileID, filePath: file, line: line, column: column).report(error)
        }
    }
}

public extension Assert where Eff: SyncTypedThrowingEffect {
    /// Asserts that the mocked method threw an error.
    ///
    /// The typed-throws counterpart of the ``Throws`` overload. The matcher stays
    /// `ArgMatcher<any Error>` so `.anyError()` and `.error(_:)` work unchanged.
    ///
    /// - Parameter errorMatcher: An `ArgMatcher<any Error>` to specify the expected error.
    ///   Defaults to `.anyError()` if `nil`, meaning any error is expected.
    /// - Parameter file: The file where a verification failure is reported.
    /// - Parameter line: The line where a verification failure is reported.
    func `throws`(
        _ errorMatcher: ArgMatcher<any Error>? = nil,
        fileID: StaticString = #fileID,
        file: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) {
        do {
            try doesThrow(errorMatcher)
        } catch {
            SourceLocation(fileID: fileID, filePath: file, line: line, column: column).report(error)
        }
    }
}

public extension Assert where Eff: AsyncTypedThrowingEffect {
    /// Asserts asynchronously that the mocked method threw an error.
    ///
    /// See the synchronous overload for why the matcher is not narrowed.
    ///
    /// - Parameter errorMatcher: An `ArgMatcher<any Error>` to specify the expected error.
    ///   Defaults to `.anyError()` if `nil`, meaning any error is expected.
    /// - Parameter file: The file where a verification failure is reported.
    /// - Parameter line: The line where a verification failure is reported.
    func `throws`(
        _ errorMatcher: ArgMatcher<any Error>? = nil,
        fileID: StaticString = #fileID,
        file: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) async {
        do {
            try await doesThrow(errorMatcher)
        } catch {
            SourceLocation(fileID: fileID, filePath: file, line: line, column: column).report(error)
        }
    }
}

private func withUntilTimeout<each Input, Eff: Effect>(
    interaction: Interaction<repeat each Input, Eff, some Any>,
    timeout: Duration,
    actionHandler: @escaping @Sendable (Action<repeat each Input, Eff>, FulfillmentTracker, @escaping @Sendable () -> Void) -> Void
) async throws
where repeat each Input: Sendable
{
    let tracker = FulfillmentTracker()
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        let actionReference = Action<repeat each Input, Eff>(invocationMatcher: interaction.invocationMatcher)
        let methodLabel = interaction.spy.methodLabel
        let timer = Task {
            try await Task.sleep(for: timeout)
            if tracker.tryFulfill() {
                interaction.spy.removeAction(actionReference)
                continuation.resume(
                    throwing: UntilError.timeout(method: methodLabel, duration: timeout)
                )
            }
        }

        let cleanup: @Sendable () -> Void = {
            timer.cancel()
            interaction.spy.removeAction(actionReference)
            continuation.resume()
        }

        actionHandler(actionReference, tracker, cleanup)
        interaction.spy.registerAction(actionReference)
    }
}

