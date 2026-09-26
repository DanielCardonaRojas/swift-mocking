import Examples
import Foundation

// Trips SwiftMocking's unrecoverable path: an unstubbed, non-throwing requirement whose
// return type has no registered default. There is nothing to return, so SwiftMocking reports
// an issue and then traps.
//
// This is a separate executable because `fatalError` takes the process down, so neither the
// crash message nor the stack it produces can be observed from inside a test. The assertions
// are made by a parent that runs this child; `ErrorReportingTests` does that.
//
// Two different properties are checked, because the routes differ in what they can offer:
//
// - the stack *frame*, which `@_transparent` controls, and which stays correct for the `spy`
//   and `conformance` routes even when no location is passed
// - the crash *message*, which is built from forwarded location arguments, and is the only
//   attribution available on the `closure` route — the closure is invoked far from where it
//   was built, so there is no meaningful frame to fall back on
switch CommandLine.arguments.dropFirst().first {
case "conformance":
    tripUnstubbedRequirementViaConformance()
case "spy":
    tripUnstubbedRequirementViaSpy()
case "typedThrows":
    tripUnstubbedTypedThrowingRequirementViaSpy()
case "closure":
    tripUnstubbedRequirementViaClosure()
case let other:
    FileHandle.standardError.write(
        Data(
            """
            usage: TrapProbe <conformance|spy|typedThrows|closure> \
            (got: \(other ?? "nothing"))

            """.utf8
        )
    )
    exit(2)
}
