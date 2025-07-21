//
//  MockableGenerator+ProtocolConformance.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 20/07/25.
//

import SwiftSyntax

func todo(_ function: StaticString = #function) -> Never {
    fatalError("Unimplemented \(function)")
}


extension MockableGenerator {
    static func makeConformanceRequirements(for protocolDecl: ProtocolDeclSyntax) -> [DeclSyntax] {
        var declarations = [DeclSyntax]()
        for member in protocolDecl.memberBlock.members {
            if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
                declarations.append(DeclSyntax(functionRequirement(functionDecl)))
            } else if let variableDecl = member.decl.as(VariableDeclSyntax.self) {
                declarations.append(DeclSyntax(variableRequirement(variableDecl)))
            } else if let subscriptDecl = member.decl.as(SubscriptDeclSyntax.self) {
                declarations.append(DeclSyntax(subscriptDecl))
            }
        }
        
        return declarations
    }
    
    static func functionRequirement(_ functionDecl: FunctionDeclSyntax) -> FunctionDeclSyntax {
        return FunctionDeclSyntax(
            name: functionDecl.name,
            signature: functionDecl.signature,
            body: functionRequirementBody(functionDecl)
        )
    }
    
    static func variableRequirement(_ variableDecl: VariableDeclSyntax) -> VariableDeclSyntax {
        todo()
    }
    
    static func subscriptRequirement(_ subscriptDecl: SubscriptDeclSyntax) -> SubscriptDeclSyntax {
        todo()
    }
    
    static func functionRequirementBody(_ funcDecl: FunctionDeclSyntax) -> CodeBlockSyntax {
        let effectType = getFunctionEffectType(funcDecl)
        return CodeBlockSyntax {
            switch effectType {
            case "None":
                baseFunctionRequirementBody(funcDecl)
            case "AsyncThrows":
                TryExprSyntax(
                    expression: AwaitExprSyntax(
                        expression: baseFunctionRequirementBody(funcDecl)
                    )
                )
            case "Throws":
                TryExprSyntax(
                    expression: baseFunctionRequirementBody(funcDecl)
                )
            case "Async":
                AwaitExprSyntax(
                    expression: baseFunctionRequirementBody(funcDecl)
                )
            default:
                baseFunctionRequirementBody(funcDecl)

            }
        }
    }
    
    private static func baseFunctionRequirementBody(_ functionDecl: FunctionDeclSyntax) -> FunctionCallExprSyntax {
        let effectType = getFunctionEffectType(functionDecl)
        let adaptingName = "adapting" + (effectType.contains("Throws") ? "Throws" : "")
        return FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(
                baseName: .identifier(adaptingName)
            ),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
                // super.log
                LabeledExprSyntax(
                    expression: MemberAccessExprSyntax(
                        base: SuperExprSyntax(),
                        name: functionDecl.name
                    )
                )
                
                // param1, param2...
                for parameter in functionDecl.signature.parameterClause.parameters {
                    LabeledExprSyntax(
                        expression: DeclReferenceExprSyntax.init(
                            baseName: parameter.secondName ?? parameter.firstName
                        )
                    )
                }
            },
            rightParen: .rightParenToken()
        )
        
    }
}

