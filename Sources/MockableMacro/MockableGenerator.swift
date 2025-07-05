//
//  MockableGenerator.swift
//  Mockable
//
//  Created by Daniel Cardona on 5/07/25.
//


import SwiftSyntax
import SwiftSyntaxBuilder

struct MacroError: Error {
  let message: String
}

public enum MockableGenerator {
    public static func processProtocol(protocolDecl: ProtocolDeclSyntax) throws -> [DeclSyntax] {
        return []
    }
}
