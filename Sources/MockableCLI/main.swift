import Foundation

import MockableGenerator

let usage = """
usage: mockable

Reads Swift source from stdin and writes a mock class for every top-level
protocol declaration to stdout. Output is byte-identical to what the
`@Mockable` macro expands to, including the `#if DEBUG` wrapper.

Generation options are read from a `@Mockable` attribute on each protocol,
when present (e.g. `@Mockable([.suffixMock])`). Protocols without the
attribute use the default options.

Example:
  echo 'protocol PricingService { func price(_ item: String) -> Int }' | mockable

Exit status:
  0  success
  1  input is not valid Swift or declares no protocol

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

func run() throws {
    let mocks = try MockableGenerator.generateMocks(source: readStdin())
    printWarnings(for: mocks)
    print(mocks.map(\.source).joined(separator: "\n\n"))
}

do {
    if CommandLine.arguments.dropFirst().contains(where: { $0 == "-h" || $0 == "--help" }) {
        print(usage)
    } else {
        try run()
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
