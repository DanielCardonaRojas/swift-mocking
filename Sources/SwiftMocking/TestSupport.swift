//
//  XCTestCase+Extensions.swift
//  Mockable
//
//  Created by Daniel Cardona on 6/07/25.
//

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
/// - Returns: A `Stub` object to configure the mock's behavior.
public func when<each Input, Eff: Effect, Output>(_ interaction: Interaction<repeat each Input, Eff, Output>) -> Stub<repeat each Input, Eff, Output> {
    interaction.spy.when(calledWith: interaction.invocationMatcher)
}

/// Verifies that a specific interaction with a mock object has occurred.
///
/// This function is used to assert that a mocked method was called with arguments
/// matching the provided `Interaction`.
/// It returns an `Assert` object, which allows you to specify the expected
/// number of calls using `.called()` or to assert that it threw an error using `.throws()`.
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

/// Verifies that a sequence of interactions with a mock object occurred in the specified order.
///
/// This function takes an array of `Interaction` objects and asserts that they were
/// called sequentially on the same mock object. If the order of calls does not match
/// the provided sequence, an issue is reported.
///
/// Example:
/// ```swift
/// verifyInOrder([
///     mock.firstMethod(),
///     mock.secondMethod(arg: 1),
///     mock.thirdMethod()
/// ])
/// ```
///
/// - Parameters:
///   - interactions: An array of `Interaction` objects representing the expected sequence of calls.
public func verifyInOrder<each Input, Eff: Effect, Output>(
    _ interactions: [Interaction<repeat each Input, Eff, Output>],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let spy = interactions[0].spy
    var matchers = [InvocationMatcher<repeat each Input>]()
    for interaction in interactions {
        matchers.append(interaction.invocationMatcher)
    }

    if !spy.verifyInOrder(matchers) {
        reportIssue("Did not find sequence of interactions", filePath: file, line: line)
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

public extension Assert where Eff: Throwing {
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
