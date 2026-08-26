import Testing
import IssueReporting
import SwiftMocking
import Foundation
@testable import Examples

/// Captures issues reported inside an operation, along with where they were attributed.
///
/// SwiftMocking reports failures through `IssueReporting`, which normally routes them to
/// the surrounding test framework. Installing this reporter instead lets a *passing* test
/// assert on what a failure would have looked like — both its message and, crucially, the
/// source location it was pinned to.
private final class IssueProbe: IssueReporter, @unchecked Sendable {
    struct Captured {
        let message: String
        /// `#fileID` form, e.g. `ExamplesTests/ErrorReportingTests.swift`.
        let fileID: String
        let line: UInt
    }

    private let lock = NSLock()
    private var _captured: [Captured] = []

    var captured: [Captured] {
        lock.lock()
        defer { lock.unlock() }
        return _captured
    }

    func reportIssue(
        _ message: @autoclosure () -> String?,
        severity: IssueSeverity,
        fileID: StaticString,
        filePath: StaticString,
        line: UInt,
        column: UInt
    ) {
        lock.lock()
        defer { lock.unlock() }
        _captured.append(
            Captured(message: message() ?? "", fileID: "\(fileID)", line: line)
        )
    }
}

/// Runs `body` with issue reporting redirected to a probe, and returns what was captured.
private func captureIssues(_ body: () -> Void) -> [IssueProbe.Captured] {
    let probe = IssueProbe()
    withIssueReporters([probe], operation: body)
    return probe.captured
}

/// Async counterpart of ``captureIssues(_:)``.
private func captureIssues(
    _ body: () async -> Void
) async -> [IssueProbe.Captured] {
    let probe = IssueProbe()
    await withIssueReporters([probe], operation: body)
    return probe.captured
}

/// Demonstrates what SwiftMocking tells you when a test goes wrong.
///
/// A mocking library is only as good as its failure messages: the value of a mock shows up
/// on the day a test breaks, not the day it passes. These tests pin the two properties that
/// determine whether a failure is actionable — *where* it points, and *what it says*.
@Suite
struct ErrorReportingTests {

    // MARK: - Where failures point

    /// A failed verification is attributed to the line that asked for it.
    ///
    /// This is the property most likely to regress silently. `IssueReporting` derives the
    /// displayed file, and swift-testing's whole `SourceLocation`, from `fileID` — not from
    /// `filePath`. A library that forwards only `filePath` still *appears* to work: the line
    /// number is right, so the failure looks plausible, while the file it names belongs to
    /// the mocking library. Clicking it lands you in someone else's source.
    @Test
    func failedVerificationPointsAtTheAssertion() {
        let mock = MockPricingService()

        let expectedLine = UInt(#line + 2)
        let issues = captureIssues {
            verify(mock.price(.any)).called(1)
        }

        let issue = try! #require(issues.first)
        #expect(issue.fileID == "\(#fileID)")
        #expect(issue.line == expectedLine)
    }

    /// Every verification entry point carries its own location, not just `called`.
    ///
    /// These share no code path beyond the reporting call, so each one has to thread the
    /// location independently — which is exactly the kind of repetition that rots.
    @Test
    func allVerificationEntryPointsCarryTheirLocation() throws {
        let mock = MockPricingService()
        when(mock.price(.any)).thenReturn(1)
        _ = try mock.price("apple")

        let neverLine = UInt(#line + 2)
        let neverIssues = captureIssues {
            verifyNever(mock.price(.any))
        }
        #expect(neverIssues.first?.line == neverLine)
        #expect(neverIssues.first?.fileID == "\(#fileID)")

        let orderLine = UInt(#line + 2)
        let orderIssues = captureIssues {
            verifyInOrder([mock.price("never-called")])
        }
        #expect(orderIssues.first?.line == orderLine)
        #expect(orderIssues.first?.fileID == "\(#fileID)")

        let zeroLine = UInt(#line + 2)
        let zeroIssues = captureIssues {
            verifyZeroInteractions(mock)
        }
        #expect(zeroIssues.first?.line == zeroLine)
        #expect(zeroIssues.first?.fileID == "\(#fileID)")
    }

    /// Two verifications of the same method report their own distinct lines.
    ///
    /// Worth pinning because it rules out a tempting shortcut: caching a location on the
    /// spy. Spies are created once per requirement and reused for every call, so a stored
    /// location would report whichever call site happened to create the spy — here, the
    /// first verification — for both failures.
    @Test
    func repeatedVerificationsReportDistinctLines() {
        let mock = MockPricingService()

        let firstLine = UInt(#line + 2)
        let first = captureIssues {
            verify(mock.price(.any)).called(1)
        }

        let secondLine = UInt(#line + 2)
        let second = captureIssues {
            verify(mock.price(.any)).called(2)
        }

        #expect(first.first?.line == firstLine)
        #expect(second.first?.line == secondLine)
        #expect(firstLine != secondLine)
    }

    /// A passing verification reports nothing at all.
    @Test
    func passingVerificationReportsNothing() throws {
        let mock = MockPricingService()
        when(mock.price(.any)).thenReturn(13)
        _ = try mock.price("apple")

        let issues = captureIssues {
            verify(mock.price(.any)).called(1)
        }
        #expect(issues.isEmpty)
    }

    // MARK: - What failures say

    /// A call-count failure names the method, what was expected, and what was recorded.
    ///
    /// "Unfulfilled call count. Actual: 0" is technically accurate and practically useless:
    /// it sends you back to the test to recover what was expected, and says nothing about
    /// what the mock actually saw.
    @Test
    func callCountFailureExplainsItself() throws {
        let mock = MockPricingService()
        when(mock.price(.any)).thenReturn(1)
        _ = try mock.price("apple")
        _ = try mock.price("banana")

        let issues = captureIssues {
            verify(mock.price("cherry")).called(1)
        }

        let message = try #require(issues.first?.message)
        // Which requirement failed.
        #expect(message.contains("price"))
        // What the mock actually saw — the usual cause of the failure.
        #expect(message.contains("(apple)"))
        #expect(message.contains("(banana)"))
    }

    /// When nothing was recorded, the message says so rather than showing an empty list.
    ///
    /// "Never called" and "called with different arguments" are different bugs with
    /// different fixes, and the message should not make you guess which one you have.
    @Test
    func neverCalledIsDistinguishedFromCalledWithOtherArguments() throws {
        let mock = MockPricingService()

        let untouched = captureIssues {
            verify(mock.price(.any)).called(1)
        }
        #expect(try #require(untouched.first?.message).contains("No invocations were recorded"))

        when(mock.price(.any)).thenReturn(1)
        _ = try mock.price("apple")

        let mismatched = captureIssues {
            verify(mock.price("cherry")).called(1)
        }
        let message = try #require(mismatched.first?.message)
        #expect(message.contains("Recorded invocations"))
        #expect(message.contains("(apple)"))
    }

    /// The implicit "at least once" default is spelled out, since it appears nowhere in the
    /// test source for the reader to check against.
    @Test
    func implicitCallCountExpectationIsSpelledOut() throws {
        let mock = MockPricingService()

        let issues = captureIssues {
            verify(mock.price(.any)).called()
        }
        #expect(try #require(issues.first?.message).contains("at least 1 call"))
    }

    /// `captured` reports the same detail when no invocation matches.
    @Test
    func capturedFailureListsRecordedInvocations() throws {
        let mock = MockPricingService()
        when(mock.price(.any)).thenReturn(1)
        _ = try mock.price("apple")

        let issues = captureIssues {
            verify(mock.price("cherry")).captured { _ in }
        }

        let message = try #require(issues.first?.message)
        #expect(message.contains("price"))
        #expect(message.contains("(apple)"))
    }

    // MARK: - Unstubbed requirements

    /// An unstubbed *throwing* requirement surfaces as a thrown `MockingError` naming the
    /// method and the arguments it was called with.
    ///
    /// Nothing is reported separately here: the thrown error already carries the full
    /// message and the test framework surfaces it at the caller's `try`. Reporting as well
    /// would duplicate one failure into two.
    @Test
    func unstubbedThrowingRequirementThrowsADescriptiveError() async {
        let mock = MockFeedService()
        let url = URL(string: "https://example.com")!

        let issues = await captureIssues {
            do {
                // `Data` has no registered default, so this reaches the unstubbed path.
                _ = try await mock.fetch(from: url)
                Issue.record("Expected the unstubbed requirement to throw")
            } catch let error as MockingError {
                #expect(error.message.contains("MockFeedService"))
                #expect(error.message.contains("fetch"))
                #expect(error.message.contains("example.com"))
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
        #expect(issues.isEmpty, "The thrown error is the report; it should not be duplicated")
    }

    /// A stubbed error propagates untouched.
    ///
    /// `thenThrow` describes behavior the test asked for, not a mocking failure, so it must
    /// not be reported as an issue.
    @Test
    func stubbedErrorsPropagateWithoutBeingReported() {
        let mock = MockPricingService()
        when(mock.price(.any)).thenThrow(ExampleError.boom)

        let issues = captureIssues {
            #expect(throws: ExampleError.boom) {
                _ = try mock.price("apple")
            }
        }
        #expect(issues.isEmpty)
    }
}

private enum ExampleError: Error, Equatable {
    case boom
}
