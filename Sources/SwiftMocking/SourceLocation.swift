//
//  SourceLocation.swift
//  SwiftMocking
//
//  Created by Daniel Cardona on 24/08/25.
//

import Foundation
import IssueReporting

/// The source location of a user's assertion, captured at the call site.
///
/// Every failure SwiftMocking reports must be attributed to the line in the *test* that
/// asked for the assertion, never to a file inside the library. Capturing all four
/// components matters: `IssueReporting` uses `fileID` — not `filePath` — to build
/// swift-testing's `SourceLocation` and to derive the module name shown in failure
/// output, so forwarding `filePath` alone attributes the failure to SwiftMocking's own
/// source file at the user's line number.
///
/// Public assertion entry points take these four values as defaulted parameters, so the
/// literals are expanded in the caller's file, and hand them to ``report(_:)``.
public struct SourceLocation: Sendable {
    @usableFromInline let fileID: StaticString
    @usableFromInline let filePath: StaticString
    @usableFromInline let line: UInt
    @usableFromInline let column: UInt

    @usableFromInline
    init(fileID: StaticString, filePath: StaticString, line: UInt, column: UInt) {
        self.fileID = fileID
        self.filePath = filePath
        self.line = line
        self.column = column
    }

    /// Captures the location of the caller.
    @inlinable
    public static func capture(
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) -> SourceLocation {
        SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
    }

    /// Reports a failure at this location, forwarding every component so the issue is
    /// attributed to the user's test rather than to SwiftMocking.
    @usableFromInline
    func report(_ message: String) {
        // Forward through a single call whose arguments are also what the test sink
        // observes, so a regression here (e.g. dropping `fileID`) is caught rather than
        // hidden behind a sink that reads the already-correct stored properties.
        Self.forward(message, fileID: fileID, filePath: filePath, line: line, column: column)
    }

    /// The one place issues leave SwiftMocking.
    ///
    /// Routed through the test sink when one is installed; otherwise handed to
    /// `IssueReporting`. All four components must be passed on — `fileID` in particular,
    /// since it is what drives the reported location and module name.
    @usableFromInline
    static func forward(
        _ message: String,
        fileID: StaticString,
        filePath: StaticString,
        line: UInt,
        column: UInt
    ) {
        if let sink = sink {
            sink(
                message,
                SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
            )
            return
        }
        reportIssue(message, fileID: fileID, filePath: filePath, line: line, column: column)
    }

    /// Test-only interception point for reported failures.
    ///
    /// Under XCTest, `reportIssue` routes straight to `_XCTFail` and never consults
    /// `IssueReporters.current`, so a custom `IssueReporter` cannot observe what location
    /// was forwarded. This hook lets SwiftMocking's own tests assert that the *caller's*
    /// location reaches the reporting call — the property that regressed when only
    /// `filePath` was forwarded.
    ///
    /// Guarded by `sinkLock` so the `nonisolated(unsafe)` storage is honest, matching the
    /// locking convention used for the mutable statics on ``Mock``.
    private nonisolated(unsafe) static var _sink: (@Sendable (String, SourceLocation) -> Void)?
    private static let sinkLock = NSLock()

    @usableFromInline
    static var sink: (@Sendable (String, SourceLocation) -> Void)? {
        sinkLock.lock()
        defer { sinkLock.unlock() }
        return _sink
    }

    /// Runs `operation`, routing reported failures to `sink` instead of the test framework.
    static func withSink(
        _ sink: @escaping @Sendable (String, SourceLocation) -> Void,
        operation: () -> Void
    ) {
        sinkLock.lock()
        let previous = _sink
        _sink = sink
        sinkLock.unlock()

        defer {
            sinkLock.lock()
            _sink = previous
            sinkLock.unlock()
        }
        operation()
    }

    /// Reports a thrown error at this location, unwrapping ``MockingError`` so its curated
    /// message is shown instead of a generic `localizedDescription`.
    @usableFromInline
    func report(_ error: any Error) {
        report(Self.describe(error))
    }

    /// Renders an error for display.
    ///
    /// ``MockingError`` carries a curated message, so it is unwrapped. Anything else is
    /// rendered with `String(reflecting:)` rather than `localizedDescription`, which for a
    /// plain Swift `Error` yields an unhelpful "The operation couldn’t be completed."
    @usableFromInline
    static func describe(_ error: any Error) -> String {
        if let error = error as? MockingError {
            return error.message
        }
        return String(reflecting: error)
    }
}

/// Reports an unrecoverable mocking failure raised from a generated mock's conformance.
///
/// A non-throwing requirement whose return type has no stub and no registered default
/// leaves nothing to return, so the process cannot continue. Reporting the issue first
/// means the test framework records a real, attributed failure — with the message and,
/// under swift-testing, the surrounding test's identity — before the trap fires, instead
/// of the run dying with only a stack trace through SwiftMocking's internals.
///
/// Prefer a registered default value (see ``DefaultProvidableRegistry``) or a stub over
/// relying on this path.
/// `@_transparent` inlines this into the caller before the optimizer runs, so the trap is
/// attributed to the calling frame rather than to `reportUnrecoverable` itself. Without it,
/// the runtime's crash message ends in `at SourceLocation.reportUnrecoverable` and Xcode's
/// stack navigator selects SwiftMocking's frame instead of the mocked requirement's.
@_transparent
@usableFromInline
func reportUnrecoverable(
    _ error: any Error,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt
) -> Never {
    let message = SourceLocation.describe(error)
    SourceLocation.forward(
        message,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
    )
    // `fatalError` defaults `file`/`line` to where it is *written*, so omitting them
    // would print "SwiftMocking/SourceLocation.swift:<line>" — pointing the user at this
    // function rather than at their own code. Passing the requirement's location through
    // makes the trap message name the `@Mockable` protocol instead.
    fatalError(message, file: filePath, line: line)
}
