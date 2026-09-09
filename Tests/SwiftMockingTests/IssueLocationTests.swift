//
//  IssueLocationTests.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 24/08/25.
//

import XCTest
@testable import SwiftMocking

/// Verifies that failures are attributed to the user's test, not to SwiftMocking.
///
/// `reportIssue` takes `fileID` *and* `filePath`, and it is `fileID` that drives
/// swift-testing's `SourceLocation` and the module name shown in failure output.
/// Forwarding only `filePath` produced a location that combined SwiftMocking's own file
/// with the user's line number — a location that does not exist. These tests pin the
/// behavior so that regression cannot return silently.
///
/// The failures are intercepted via ``SourceLocation/withSink(_:operation:)`` rather than a
/// custom `IssueReporter`: under XCTest, `reportIssue` routes directly to `_XCTFail` and
/// never consults `IssueReporters.current`.
final class IssueLocationTests: XCTestCase {
    private struct Captured {
        let message: String
        let fileID: String
        let filePath: String
        let line: UInt
        let column: UInt
    }

    private func captureIssues(during operation: () -> Void) -> [Captured] {
        let lock = NSLock()
        nonisolated(unsafe) var captured: [Captured] = []
        SourceLocation.withSink({ message, location in
            lock.lock()
            defer { lock.unlock() }
            captured.append(
                Captured(
                    message: message,
                    fileID: "\(location.fileID)",
                    filePath: "\(location.filePath)",
                    line: location.line,
                    column: location.column
                )
            )
        }, operation: operation)
        return captured
    }

    private func assertAttributedToThisFile(
        _ captured: [Captured],
        expectedLine: UInt,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let issue = captured.first else {
            return XCTFail("Expected an issue to be reported", file: file, line: line)
        }
        XCTAssertEqual(issue.fileID, "\(#fileID)", "fileID must point at the test", file: file, line: line)
        XCTAssertEqual(issue.filePath, "\(#filePath)", "filePath must point at the test", file: file, line: line)
        XCTAssertEqual(issue.line, expectedLine, "line must point at the assertion", file: file, line: line)
        XCTAssertGreaterThan(issue.column, 0, "column must be captured", file: file, line: line)
    }

    func testCalledReportsAtCallSite() {
        let spy = Spy<String, None, Void>()
        var line: UInt = 0
        let captured = captureIssues {
            line = UInt(#line + 1)
            verify(spy(.any)).called(1)
        }
        assertAttributedToThisFile(captured, expectedLine: line)
    }

    func testNeverCalledReportsAtCallSite() {
        let spy = Spy<String, None, Void>()
        when(spy(.any)).thenReturn(())
        spy("called")

        var line: UInt = 0
        let captured = captureIssues {
            line = UInt(#line + 1)
            verify(spy(.any)).neverCalled()
        }
        assertAttributedToThisFile(captured, expectedLine: line)
    }

    func testVerifyNeverReportsAtCallSite() {
        let spy = Spy<String, None, Void>()
        when(spy(.any)).thenReturn(())
        spy("called")

        var line: UInt = 0
        let captured = captureIssues {
            line = UInt(#line + 1)
            verifyNever(spy(.any))
        }
        assertAttributedToThisFile(captured, expectedLine: line)
    }

    func testCapturedReportsAtCallSite() {
        let spy = Spy<String, None, Void>()
        var line: UInt = 0
        let captured = captureIssues {
            line = UInt(#line + 1)
            verify(spy(.any)).captured { _ in }
        }
        assertAttributedToThisFile(captured, expectedLine: line)
    }

    func testThrowsReportsAtCallSite() {
        let spy = Spy<String, Throws, Void>()
        var line: UInt = 0
        let captured = captureIssues {
            line = UInt(#line + 1)
            verify(spy(.any)).throws()
        }
        assertAttributedToThisFile(captured, expectedLine: line)
    }

    func testVerifyInOrderReportsAtCallSite() {
        let spy = Spy<String, None, Void>()
        var line: UInt = 0
        let captured = captureIssues {
            line = UInt(#line + 1)
            verifyInOrder([spy(.equal("never"))])
        }
        assertAttributedToThisFile(captured, expectedLine: line)
    }

    func testVerifyZeroInteractionsReportsAtCallSite() {
        let mock = Mock()
        let spy: Spy<String, None, Void> = mock.someMethod
        when(spy(.any)).thenReturn(())
        spy("called")

        var line: UInt = 0
        let captured = captureIssues {
            line = UInt(#line + 1)
            verifyZeroInteractions(mock)
        }
        assertAttributedToThisFile(captured, expectedLine: line)
    }

    /// The enriched message must name the method and show what was actually recorded,
    /// so a failure is diagnosable without re-reading the test.
    func testReportedMessageNamesTheMethodAndRecordedInvocations() {
        let mock = Mock()
        let spy: Spy<String, None, Void> = mock.fetch
        when(spy(.any)).thenReturn(())
        spy("actual")

        let captured = captureIssues {
            verify(spy(.equal("expected"))).called(1)
        }
        let message = captured.first?.message ?? ""
        XCTAssertTrue(message.contains("fetch"), message)
        XCTAssertTrue(message.contains("(actual)"), message)
    }

    /// A verification that passes must report nothing at all.
    func testNoIssueReportedOnSuccess() {
        let spy = Spy<String, None, Void>()
        when(spy(.any)).thenReturn(())
        spy("called")

        let captured = captureIssues {
            verify(spy(.any)).called(1)
        }
        XCTAssertTrue(captured.isEmpty, "Expected no issues, got: \(captured.map(\.message))")
    }
}
