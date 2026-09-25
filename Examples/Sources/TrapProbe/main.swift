import Examples
import Foundation

// Trips SwiftMocking's unrecoverable path: an unstubbed, non-throwing requirement whose
// return type has no registered default. There is nothing to return, so SwiftMocking reports
// an issue and then traps.
//
// This is a separate executable because the property under test is which *stack frame* the
// trap is attributed to, and `fatalError` takes the process down. The assertion has to be
// made by a parent that runs this child under a debugger; `ErrorReportingTests` does that.
//
// Note that the crash *message* is not the interesting part: it is built from the location
// arguments SwiftMocking forwards, and stays correct even when the attribution regresses.
// Only the backtrace distinguishes them, which is why the test inspects frames.
switch CommandLine.arguments.dropFirst().first {
case "conformance":
    tripUnstubbedRequirementViaConformance()
case "spy":
    tripUnstubbedRequirementViaSpy()
case let other:
    FileHandle.standardError.write(
        Data("usage: TrapProbe <conformance|spy> (got: \(other ?? "nothing"))\n".utf8)
    )
    exit(2)
}
