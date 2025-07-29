//
//  MockableMacro.swift
//  Mockable
//
//  Created by Daniel Cardona on 5/07/25.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import MockableGenerator

@main
public struct MockablePlugin: CompilerPlugin {
    public let providingMacros: [Macro.Type] = [
        MockableMacro.self,
    ]

    public init() { }
}

public struct MacroError: Error {
    public let message: String
}

public enum MockableMacro: PeerMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            throw MacroError(message: "@WitnessMacro only works on protocols declarations")
        }

        let mockableDecls = try MockableGenerator.processProtocol(protocolDecl: protocolDecl)
        var allDecls: [DeclSyntax] = []

        allDecls.append(contentsOf: mockableDecls)
        return allDecls
    }
}
