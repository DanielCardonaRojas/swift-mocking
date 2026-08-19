import SwiftBasicFormat
import SwiftDiagnostics
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

import SwiftMockingOptions

/// The result of generating a mock for a single protocol declaration.
public struct GeneratedMock: Equatable, Sendable {
    /// The name of the protocol the mock was generated from.
    public let protocolName: String

    /// The formatted mock declaration, including its `#if DEBUG` wrapper.
    public let source: String

    /// Names of protocols the source protocol inherits, excluding memberless
    /// bases (`AnyObject`, `class`, `Sendable`).
    ///
    /// Non-empty when the generated mock may fail to conform, because the
    /// generator does not emit implementations for inherited requirements.
    public let inheritedTypeNames: [String]

    public init(protocolName: String, source: String, inheritedTypeNames: [String]) {
        self.protocolName = protocolName
        self.source = source
        self.inheritedTypeNames = inheritedTypeNames
    }
}

/// Errors thrown while generating mocks from Swift source.
public enum MockableGeneratorError: Error, Equatable, CustomStringConvertible {
    /// The input parsed successfully but contains no top-level protocol declaration.
    case noProtocolsFound

    /// The input is not valid Swift. The payload carries compiler-style
    /// annotated diagnostics describing every parse error.
    case parseFailed(diagnostics: String)

    public var description: String {
        switch self {
        case .noProtocolsFound:
            "no protocol declaration found in input"
        case .parseFailed(let diagnostics):
            "input failed to parse as Swift:\n\(diagnostics)"
        }
    }
}

public extension MockableGenerator {
    /// Generates a mock class for every top-level protocol declaration in the given Swift source.
    ///
    /// This is the pipeline behind the `mockable` command line tool. It parses
    /// the source, runs the same generation used by the `@Mockable` macro, and
    /// formats the result exactly like macro expansion output, so mocks
    /// generated here are byte-identical to their macro-generated counterparts.
    ///
    /// Options are read from a `@Mockable` attribute on each protocol, when
    /// present. A protocol without the attribute uses the default options.
    ///
    /// - Parameter source: Swift source text containing at least one top-level
    ///   protocol declaration.
    /// - Returns: One `GeneratedMock` per protocol, in declaration order.
    /// - Throws: `MockableGeneratorError.parseFailed` if the source has syntax
    ///   errors, `MockableGeneratorError.noProtocolsFound` if it declares no
    ///   top-level protocols.
    static func generateMocks(source: String) throws -> [GeneratedMock] {
        let sourceFile = Parser.parse(source: source)

        let diagnostics = ParseDiagnosticsGenerator.diagnostics(for: sourceFile)
        if diagnostics.contains(where: { $0.diagMessage.severity == .error }) {
            throw MockableGeneratorError.parseFailed(
                diagnostics: DiagnosticsFormatter.annotatedSource(tree: sourceFile, diags: diagnostics)
            )
        }

        let protocolDecls = sourceFile.statements.compactMap { $0.item.as(ProtocolDeclSyntax.self) }
        guard !protocolDecls.isEmpty else {
            throw MockableGeneratorError.noProtocolsFound
        }

        return try protocolDecls.map { protocolDecl in
            let mockSource = try processProtocol(protocolDecl: protocolDecl)
                .map { decl in
                    decl.formatted(using: BasicFormat(indentationWidth: .spaces(4)))
                        .trimmedDescription(matching: \.isWhitespace)
                }
                .joined(separator: "\n\n")

            return GeneratedMock(
                protocolName: protocolDecl.name.text,
                source: mockSource,
                inheritedTypeNames: inheritedTypeNames(of: protocolDecl)
            )
        }
    }

    /// Collects the protocols a declaration inherits, dropping bases that
    /// carry no requirements (`AnyObject`, `class`, `Sendable`).
    private static func inheritedTypeNames(of protocolDecl: ProtocolDeclSyntax) -> [String] {
        let memberlessBases: Set<String> = ["AnyObject", "class", "Sendable"]
        return protocolDecl.inheritanceClause?.inheritedTypes
            .map { $0.type.trimmedDescription }
            .filter { !memberlessBases.contains($0) } ?? []
    }
}
