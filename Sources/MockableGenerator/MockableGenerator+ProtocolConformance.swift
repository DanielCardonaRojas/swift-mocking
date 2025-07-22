//
//  MockableGenerator+ProtocolConformance.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 20/07/25.
//

import SwiftSyntax

extension MockableGenerator {
    static func makeConformanceRequirements(for protocolDecl: ProtocolDeclSyntax) -> [DeclSyntax] {
        var declarations = [DeclSyntax]()
        for member in protocolDecl.memberBlock.members {
            if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
                declarations.append(DeclSyntax(functionRequirement(functionDecl)))
            } else if let variableDecl = member.decl.as(VariableDeclSyntax.self) {
                declarations.append(DeclSyntax(variableRequirement(variableDecl)))
            } else if let subscriptDecl = member.decl.as(SubscriptDeclSyntax.self) {
                declarations.append(DeclSyntax(subscriptRequirement(subscriptDecl)))
            } else if let initDecl = member.decl.as(InitializerDeclSyntax.self) {
                declarations.append(DeclSyntax(initializerRequirement(initDecl)))

            }
        }
        
        return declarations
    }

    static func initializerRequirement(
        _ initDecl: InitializerDeclSyntax
    ) -> InitializerDeclSyntax {
        let modifiers = DeclModifierListSyntax {
            DeclModifierSyntax(name: .keyword(.required))
            for modifier in initDecl.modifiers {
                modifier
            }
        }
        return InitializerDeclSyntax(
            attributes: initDecl.attributes,
            modifiers: modifiers,
            genericParameterClause: initDecl.genericParameterClause,
            signature: initDecl.signature,
            body: CodeBlockSyntax {

            }
        )
    }

    static func functionRequirement(_ functionDecl: FunctionDeclSyntax) -> FunctionDeclSyntax {
        return FunctionDeclSyntax(
            attributes: functionDecl.attributes,
            modifiers: functionDecl.modifiers,
            name: functionDecl.name,
            genericParameterClause: functionDecl.genericParameterClause,
            signature: functionDecl.signature,
            body: functionRequirementBody(functionDecl)
        )
    }
    
    static func variableRequirement(_ variableDecl: VariableDeclSyntax) -> VariableDeclSyntax {
        return VariableDeclSyntax(
            leadingTrivia: .newline,
            attributes: variableDecl.attributes,
            modifiers: variableDecl.modifiers.trimmed,
            bindingSpecifier: variableDecl.bindingSpecifier,
            bindings: PatternBindingListSyntax {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(
                        identifier: variableDecl.name
                    ),
                    typeAnnotation: variableDecl.bindings.first?.typeAnnotation,
                    accessorBlock: AccessorBlockSyntax(
                        accessors: .accessors(
                            AccessorDeclListSyntax(
                                itemsBuilder: {
                                    // Setter
                                    if variableDecl.hasSetter {
                                        AccessorDeclSyntax(
                                            accessorSpecifier: .keyword(.set),
                                            bodyBuilder: {
                                                ReturnStmtSyntax(
                                                    expression: adaptCall(
                                                        effectType: .none,
                                                        requirementName: .identifier("set\(variableDecl.name.text.capitalized)"),
                                                        parameters: [.identifier("newValue")]
                                                    )
                                                )
                                            }
                                        )
                                    }
                                    // Getter
                                    AccessorDeclSyntax(
                                        accessorSpecifier: .keyword(.get),
                                        bodyBuilder: {
                                            adaptCall(
                                                effectType: .none,
                                                requirementName: variableDecl.name,
                                                parameters: []
                                            )
                                        }
                                    )

                            })
                        )
                    )
                )

            }
        )
    }
    
    static func subscriptRequirement(_ subscriptDecl: SubscriptDeclSyntax) -> SubscriptDeclSyntax {
        SubscriptDeclSyntax(
            attributes: subscriptDecl.attributes,
            modifiers: subscriptDecl.modifiers,
            parameterClause: subscriptDecl.parameterClause,
            returnClause: subscriptDecl.returnClause,
            genericWhereClause: subscriptDecl.genericWhereClause,
            accessorBlock: AccessorBlockSyntax(
                accessors: .accessors(
                    AccessorDeclListSyntax {
                        AccessorDeclSyntax(
                            accessorSpecifier: .keyword(.get),
                            bodyBuilder: {
                                ReturnStmtSyntax(
                                    expression: adaptCall(
                                        effectType: .none,
                                        requirementName: .identifier("subscript"),
                                        parameters: subscriptDecl.parameterClause.parameters.map({ $0.secondName ?? $0.firstName })
                                    )
                                )
                            }
                        )
                    })
            )
        )
    }

    static func functionRequirementBody(_ funcDecl: FunctionDeclSyntax) -> CodeBlockSyntax {
        let effectType = getFunctionEffectType(funcDecl)
        return CodeBlockSyntax {
            switch effectType {
            case .none:
                ReturnStmtSyntax(expression: baseFunctionRequirementBody(funcDecl))
            case .asyncThrows:
                ReturnStmtSyntax(
                    expression: TryExprSyntax(
                        expression: AwaitExprSyntax(
                            expression: baseFunctionRequirementBody(funcDecl)
                        )
                    )
                )
            case .throws:
                ReturnStmtSyntax(
                    expression: TryExprSyntax(
                        expression: baseFunctionRequirementBody(funcDecl)
                    )
                )
            case .async:
                ReturnStmtSyntax(
                    expression: AwaitExprSyntax(
                        expression: baseFunctionRequirementBody(funcDecl)
                    )
                )
            }
        }
    }
    
    private static func baseFunctionRequirementBody(_ functionDecl: FunctionDeclSyntax) -> FunctionCallExprSyntax {
        let effectType = getFunctionEffectType(functionDecl)
        return adaptCall(
            effectType: effectType,
            requirementName: functionDecl.name,
            parameters: functionDecl.signature.parameterClause.parameters
                .map({ $0.secondName ?? $0.firstName})
        )
    }

    private static func adaptCall(effectType: EffectType, requirementName: TokenSyntax, parameters: [TokenSyntax]) -> FunctionCallExprSyntax {
        let adaptingName = "adapt" + (effectType.rawValue.contains("Throws") ? "Throwing" : "")
        return FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(
                baseName: .identifier(adaptingName)
            ),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
                // super.myMethoName
                LabeledExprSyntax(
                    expression: MemberAccessExprSyntax(
                        base: SuperExprSyntax(),
                        name: requirementName
                    )
                )

                // param1, param2...
                for parameter in parameters {
                    LabeledExprSyntax(
                        expression: DeclReferenceExprSyntax.init(
                            baseName: parameter
                        )
                    )
                }
            },
            rightParen: .rightParenToken()
        )

    }
}

