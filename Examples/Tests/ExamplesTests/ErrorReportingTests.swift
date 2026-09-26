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
                // `FeedService` is mocked with `.composition`, so its spies live on a
                // bare `Mock` instance and are labelled "Mock.fetch" rather than
                // "MockFeedService.fetch" — the composing type's name is not available
                // where the label is built. Inheriting mocks do name themselves.
                #expect(error.message.contains("Mock"))
                #expect(error.message.contains("fetch"))
                #expect(error.message.contains("example.com"))
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
        #expect(issues.isEmpty, "The thrown error is the report; it should not be duplicated")
    }

    /// A non-throwing requirement backed by a registered default reports nothing.
    ///
    /// The unstubbed *trapping* case cannot be asserted in-process at all — `fatalError` takes
    /// the process down — so it is covered out-of-process by
    /// ``trapIsAttributedToUserCodeNotSwiftMocking(route:expectedFrame:)``. What this pins is
    /// the boundary next to it: a non-throwing call that the registry *can* satisfy must
    /// return quietly, rather than reporting a spurious issue on the way.
    @Test
    func nonThrowingRequirementWithADefaultReportsNothing() {
        let issues = captureIssues {
            let mock = MockReportOnlyService()
            // `Void` is registered, so this resolves without a stub and returns normally.
            mock.record(id: "alice")
        }

        #expect(issues.isEmpty)
    }

    /// The trap from an unstubbed non-throwing requirement is attributed to user code.
    ///
    /// This is the property that makes an unstubbed call debuggable in Xcode: the stack frame
    /// the debugger selects must be the user's call, not a file inside SwiftMocking. It holds
    /// only if every frame between the call and `fatalError` is `@_transparent`, so the trap
    /// is inlined into the caller before the optimizer runs.
    ///
    /// Asserting on the crash *message* would not catch a regression here. The message is
    /// built from the location arguments SwiftMocking forwards explicitly, so it keeps naming
    /// the right file even when the attribution breaks. Only the backtrace distinguishes the
    /// two, so this runs the probe under `lldb` and inspects the frames.
    ///
    /// Both routes into the unrecoverable path are covered: a generated conformance
    /// (`Mock.adapt`) and a directly constructed spy (`Spy.callAsFunction`). They reach the
    /// trap through different frames, so a regression can appear in one and not the other.
    ///
    /// The two land in different — but equally correct — places, so each asserts its own
    /// expected frame:
    ///
    /// - `spy`: the user's own function, in `MockedProtocols.swift`. A directly invoked spy
    ///   captures its caller's location in defaulted parameters, so this route gets a correct
    ///   crash *message* as well.
    /// - `conformance`: the generated mock's method, which lives in the macro expansion
    ///   buffer (`@__swiftmacro_…`) and which Xcode resolves back to the `@Mockable`
    ///   protocol. A conformance witness must match the requirement's signature exactly, so
    ///   it has nowhere to carry a location; its crash *message* therefore names
    ///   SwiftMocking's own file. The frame is what makes this route debuggable, and the
    ///   frame is what this test pins.
    ///
    /// Requires `lldb` and the `TrapProbe` executable, so it is macOS-only and disabled when
    /// the probe has not been built. `swift test` builds it as part of the package, but a
    /// filtered run that skips the build would otherwise fail for the wrong reason.
    @Test(
        .enabled(if: trapProbeIsAvailable, "TrapProbe executable or lldb is unavailable"),
        arguments: [
            ("spy", "MockedProtocols.swift"),
            ("conformance", "@__swiftmacro_"),
        ]
    )
    func trapIsAttributedToUserCodeNotSwiftMocking(route: String, expectedFrame: String) throws {
        let backtrace = try runTrapProbeUnderDebugger(route: route)

        // The frame the debugger selects must belong to the caller, not to the library. With a
        // merely `@inlinable` frame in the chain this reads
        // `reportUnrecoverable() at <compiler-generated>:0` instead.
        #expect(
            backtrace.contains(expectedFrame),
            """
            Trap was not attributed to the calling code.
            Route: \(route), expected frame to mention: \(expectedFrame)
            Backtrace:
            \(backtrace)
            """
        )
        #expect(
            !backtrace.contains("reportUnrecoverable"),
            """
            Trap was attributed to SwiftMocking's own reporting helper, which means a frame \
            in the chain lost `@_transparent`.
            Route: \(route)
            Backtrace:
            \(backtrace)
            """
        )
        #expect(
            !backtrace.contains("<compiler-generated>"),
            """
            Trap was attributed to a compiler-generated frame with no source location.
            Route: \(route)
            Backtrace:
            \(backtrace)
            """
        )
    }

    /// A spy injected as a closure names the line that wired up the dependency.
    ///
    /// This is the shape used for closure-based dependencies:
    ///
    /// ```swift
    /// struct FetchClient { var load: (Int) -> Item }
    /// let client = FetchClient(load: adapt(spy))
    /// ```
    ///
    /// The closure escapes and is invoked somewhere else entirely, so there is no useful
    /// stack frame to fall back on — unlike the other two routes, the crash *message* is the
    /// only attribution available. `adapt` captures the location at its own call site and
    /// threads it through `asFunction` into the closure to provide it.
    ///
    /// Without that, the `self(...)` call inside `asFunction` supplies its own defaults,
    /// which expand inside `Spy.swift`, and the failure is reported against SwiftMocking's
    /// own source — the exact problem this whole area exists to prevent.
    /// Unlike the backtrace tests this needs no debugger, so it also runs on CI.
    @Test(.enabled(if: trapProbeCanRun, "TrapProbe executable is unavailable"))
    func closureDependencyTrapNamesTheInjectionSite() throws {
        let output = try runTrapProbe(route: "closure")

        #expect(
            output.contains("Examples/MockedProtocols.swift"),
            """
            The trap did not name the file where the closure dependency was built. A location \
            dropped between `adapt`, `asFunction`, and the escaping closure falls back to \
            SwiftMocking's own source.
            Output:
            \(output)
            """
        )
        #expect(
            !output.contains("SwiftMocking/Spy.swift"),
            """
            The trap was attributed to Spy.swift, which means the injection site's location \
            was not threaded through to the closure.
            Output:
            \(output)
            """
        )
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

/// Whether the backtrace check can run at all: macOS, with the probe built and a usable
/// developer directory.
/// Whether the probe can simply be *run* — no debugger, so this holds on CI too.
private let trapProbeCanRun: Bool = {
    #if os(macOS)
    return trapProbeURL != nil && testFrameworksPath != nil
    #else
    return false
    #endif
}()

/// Whether the probe can be run *under lldb*, which is stricter: see below.
private let trapProbeIsAvailable: Bool = {
    #if os(macOS)
    // Skipped on CI: attaching a debugger needs authorization that hosted runners do not
    // reliably grant, and a refused attach makes lldb block rather than fail. This is a
    // local-only check by design — the source-level guard in SwiftMockingTests'
    // `TrapAttributionTests` is what protects the same invariant on CI.
    guard ProcessInfo.processInfo.environment["CI"] == nil else { return false }
    return trapProbeURL != nil && testFrameworksPath != nil
    #else
    return false
    #endif
}()

/// Runs the `TrapProbe` executable directly and returns its crash output.
///
/// No debugger involved, unlike ``runTrapProbeUnderDebugger(route:)``: this reads the message
/// `fatalError` prints, which is what carries the attribution on routes that have no useful
/// stack frame. That also makes it safe to run anywhere, since nothing needs to attach.
private func runTrapProbe(route: String) throws -> String {
    let probe = try locateTrapProbe()
    let frameworks = try #require(
        testFrameworksPath,
        "Could not locate the platform test frameworks directory via xcode-select."
    )

    let process = Process()
    process.executableURL = probe
    process.arguments = [route]
    // SwiftMocking links swift-testing (via IssueReporting), which lives only on the test
    // frameworks path, so a plain executable cannot resolve it unaided.
    var environment = ProcessInfo.processInfo.environment
    environment["DYLD_FRAMEWORK_PATH"] = frameworks
    process.environment = environment

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    process.standardInput = FileHandle.nullDevice

    try process.run()

    let watchdog = DispatchWorkItem { if process.isRunning { process.terminate() } }
    DispatchQueue.global().asyncAfter(deadline: .now() + 60, execute: watchdog)
    defer { watchdog.cancel() }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    let output = String(decoding: data, as: UTF8.self)

    try #require(
        output.contains("Fatal error"),
        """
        Expected the probe to trap but it did not. Output:
        \(output)
        """
    )
    return output
}

/// Runs the `TrapProbe` executable under `lldb` and returns the backtrace of its crash.
///
/// A debugger is required because the property under test is which stack frame the trap is
/// attributed to — the same thing Xcode's stack navigator selects. The crash message alone
/// cannot distinguish a correct attribution from a regressed one.
///
/// - Parameter route: Which path into the unrecoverable path to exercise, matching the
///   arguments `TrapProbe` accepts.
private func runTrapProbeUnderDebugger(route: String) throws -> String {
    let probe = try locateTrapProbe()
    let frameworks = try #require(
        testFrameworksPath,
        "Could not locate the platform test frameworks directory via xcode-select."
    )

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    process.arguments = [
        "lldb", "--batch",
        // SwiftMocking links swift-testing (via IssueReporting), which lives only on the
        // test frameworks path, so a plain executable cannot resolve it unaided.
        "-o", "settings set target.env-vars DYLD_FRAMEWORK_PATH=\(frameworks)",
        "-o", "run",
        "-o", "bt",
        "--", probe.path, route,
    ]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    // lldb prompts for input if it cannot run the target; without a closed stdin it would
    // sit on that prompt forever rather than failing.
    process.standardInput = FileHandle.nullDevice

    try process.run()

    // Kill the debugger if it stalls. `lldb` needs authorization to attach on some machines,
    // and when it is refused it can block indefinitely — which, without this, hangs the whole
    // test run instead of failing one test.
    let watchdog = DispatchWorkItem { if process.isRunning { process.terminate() } }
    DispatchQueue.global().asyncAfter(deadline: .now() + 90, execute: watchdog)
    defer { watchdog.cancel() }

    // Read before waiting, so a large backtrace cannot fill the pipe and deadlock.
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    let output = String(decoding: data, as: UTF8.self)

    // Keep only the frame lines; the surrounding lldb chatter is noise in failure messages.
    let frames = output
        .split(separator: "\n", omittingEmptySubsequences: true)
        .filter { $0.contains("frame #") }
        .joined(separator: "\n")

    // An empty backtrace means the probe never trapped, or lldb could not run it. Either way
    // the test cannot conclude anything, so fail loudly rather than vacuously passing.
    try #require(
        !frames.isEmpty,
        """
        Expected a backtrace from the trap probe but captured none. \
        Full lldb output:
        \(output)
        """
    )

    return frames
}

/// Locates the `TrapProbe` executable in the same build directory as this test bundle.
///
/// Anchored on the bundle *containing this test code* rather than `Bundle.main`: under
/// `swift test` the main bundle is the toolchain's test runner, which lives nowhere near the
/// package's build products. The probe is a product of this same package, so it sits in the
/// build directory alongside the test bundle — walking up from there works across
/// debug/release and architecture-specific directories without hardcoding a path.
private func locateTrapProbe() throws -> URL {
    return try #require(
        trapProbeURL,
        """
        Could not find the TrapProbe executable. Looked in:
        \(trapProbeCandidates.map(\.path).joined(separator: "\n"))
        Build it with `swift build --product TrapProbe`.
        """
    )
}

/// Directories to search for the probe, nearest first.
///
/// `.xctest` bundles nest the binary under `Contents/MacOS`, so several levels are tried.
private let trapProbeCandidates: [URL] = {
    let bundle = Bundle(for: BundleAnchor.self).bundleURL
    return (1...4).map { depth in
        var directory = bundle
        for _ in 0..<depth { directory = directory.deletingLastPathComponent() }
        return directory.appendingPathComponent("TrapProbe")
    }
}()

private let trapProbeURL: URL? = trapProbeCandidates.first {
    FileManager.default.isExecutableFile(atPath: $0.path)
}

/// Anchors ``locateTrapProbe()`` to the bundle holding this test code.
private final class BundleAnchor {}

/// Path to the platform's test frameworks, where swift-testing's `Testing.framework` lives.
///
/// Derived from the active developer directory rather than hardcoded, so it follows
/// `xcode-select` and a non-standard Xcode location.
private let testFrameworksPath: String? = {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    process.arguments = ["xcode-select", "--print-path"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
    } catch {
        return nil
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    let developerDirectory = String(decoding: data, as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !developerDirectory.isEmpty else { return nil }

    let frameworks = developerDirectory
        + "/Platforms/MacOSX.platform/Developer/Library/Frameworks"
    guard FileManager.default.fileExists(atPath: frameworks) else { return nil }
    return frameworks
}()
