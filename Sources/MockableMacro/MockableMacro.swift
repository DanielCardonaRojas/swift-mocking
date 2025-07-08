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
struct MockablePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        MockableMacro.self,
    ]
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
    return try MockableGenerator.processProtocol(protocolDecl: protocolDecl)
  }
}

