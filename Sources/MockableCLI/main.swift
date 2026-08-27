import Foundation

import MockableGenerator
import SwiftMockingOptions

let usage = """
usage: mockable [--options <list>] [--no-debug-wrap]

Build once with: swift build -c release --product mockable
Binary: .build/release/mockable

Reads Swift source from stdin and writes a mock class for every top-level
protocol declaration to stdout. Output is byte-identical to what the
`@Mockable` macro expands to, including the `#if DEBUG` wrapper. The input
does not need to be annotated — a bare protocol is mocked as-is.

--options <list>  Comma-separated generation options applied to protocols
                  that carry no `@Mockable` attribute of their own, so
                  protocols you cannot annotate (a third-party library's,
                  say) still reach every generation strategy. Recognized:
                  \(MockableOptions.allIdentifiers.joined(separator: ", ")).
                  Leading dots are accepted, so both `composition` and
                  `.composition` work. Defaults to \(MockableOptions.default.identifiers.joined(separator: ", ")).

                  A protocol that *does* carry `@Mockable([...])` keeps the
                  options written there; this flag never overrides them.

                  Use `.composition` for a protocol with a class constraint
                  (`protocol Service: UIViewController`), which cannot be
                  mocked by the default inheriting strategy.

--no-debug-wrap   Emit the mock class bare, without the `#if DEBUG` wrapper
                  the macro emits — the right choice when pasting into a test
                  target, since DEBUG is defined per build configuration (not
                  per target) and a wrapped mock vanishes under
                  `swift test -c release`.

Examples:
  echo 'protocol PricingService { func price(_ item: String) -> Int }' | mockable
  echo 'protocol Service: SomeBase { func load() }' | mockable --options composition

Exit status:
  0  success
  1  input is not valid Swift, declares no protocol, or arguments are invalid

Warnings (e.g. a protocol that inherits another protocol, whose inherited
requirements the generator does not implement) are written to stderr; stdout
only ever carries generated code.
"""

func readStdin() throws -> String {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard let source = String(data: data, encoding: .utf8) else {
        throw MockableGeneratorError.parseFailed(diagnostics: "input is not valid UTF-8")
    }
    return source
}

func printWarnings(for mocks: [GeneratedMock]) {
    for mock in mocks {
        for inheritedTypeName in mock.inheritedTypeNames {
            FileHandle.standardError.write(
                Data(
                    (
                        "warning: mock for protocol '\(mock.protocolName)' does not implement " +
                        "requirements inherited from '\(inheritedTypeName)' and may fail to conform\n"
                    ).utf8
                )
            )
        }
    }
}

func run(includeDebugWrapper: Bool, defaultOptions: MockableOptions) throws {
    let mocks = try MockableGenerator.generateMocks(
        source: readStdin(),
        includeDebugWrapper: includeDebugWrapper,
        defaultOptions: defaultOptions
    )
    printWarnings(for: mocks)
    print(mocks.map(\.source).joined(separator: "\n\n"))
}

/// Fails with the given message and the usage text, as a bad invocation is a
/// usage error rather than a generation failure.
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n\n\(usage)\n".utf8))
    exit(1)
}

struct Arguments {
    var includeDebugWrapper = true
    var defaultOptions = MockableOptions.default
    var showHelp = false
}

func parseArguments(_ arguments: [String]) -> Arguments {
    var parsed = Arguments()
    var index = arguments.startIndex

    while index < arguments.endIndex {
        let argument = arguments[index]
        switch argument {
        case "-h", "--help":
            parsed.showHelp = true
        case "--no-debug-wrap":
            parsed.includeDebugWrapper = false
        case "--options":
            index += 1
            guard index < arguments.endIndex else {
                fail("'--options' requires a value, e.g. --options composition")
            }
            let value = arguments[index]
            // The generator's own parser, so the CLI accepts exactly what the
            // macro's attribute does — including a bracketed, dotted list.
            guard let options = MockableOptions(stringLiteral: value) else {
                fail(
                    "unrecognized option in '--options \(value)' " +
                    "(recognized: \(MockableOptions.allIdentifiers.joined(separator: ", ")))"
                )
            }
            parsed.defaultOptions = options
        default:
            fail("unsupported argument '\(argument)'")
        }
        index += 1
    }
    return parsed
}

do {
    let arguments = parseArguments(Array(CommandLine.arguments.dropFirst()))
    if arguments.showHelp {
        print(usage)
    } else {
        try run(
            includeDebugWrapper: arguments.includeDebugWrapper,
            defaultOptions: arguments.defaultOptions
        )
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
