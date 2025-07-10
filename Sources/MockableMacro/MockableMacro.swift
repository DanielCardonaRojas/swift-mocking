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
import WitnessGenerator
import MockableTypes

@main
struct MockablePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        MockableMacro.self,
        WitnessMacro.self,
    ]
}

struct MacroError: Error {
    let message: String
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

        let codeGenOptions = MockableGenerator.codeGenOptions(protocolDecl: protocolDecl)

        let witnessDecls = try WitnessGenerator.processProtocol(
            protocolDecl: protocolDecl,
            options: .synthesizedConformance
        )
        let mockableDecls = try MockableGenerator.processProtocol(protocolDecl: protocolDecl)
        var allDecls: [DeclSyntax] = []

        if codeGenOptions.contains(.includeWitness) {
            allDecls.append(contentsOf: witnessDecls)

        }

        allDecls.append(contentsOf: mockableDecls)
        return allDecls
    }
}

public enum WitnessMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            throw MacroError(message: "@WitnessMacro only works on protocols declarations")
        }

        let witnessDecls = try WitnessGenerator.processProtocol(
            protocolDecl: protocolDecl,
            options: .synthesizedConformance
        )
        return witnessDecls
    }

}

