//
//  MockableGenerator+ProtocolConformance.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 20/07/25.
//

import SwiftSyntax

extension MockableGenerator {
    /// Generates the necessary declarations to conform to a protocol.
    ///
    /// This function iterates through the members of a protocol and generates the corresponding
    /// function, variable, subscript, and initializer requirements.
    ///
    /// For example, for the following protocol:
    /// ```swift
    /// protocol MyService {
    ///     func doSomething()
    ///     var value: Int { get }
    /// }
    /// ```
    /// This function will generate the `doSomething()` function and the `value` computed property.
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

    /// Generates a `required` initializer declaration.
    ///
    /// For an initializer `init(value: Int)`, this will generate:
    /// ```swift
    /// required init(value: Int) {
    ///     // ...
    /// }
    /// ```
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

    /// Generates a function declaration that fulfills a protocol requirement.
    ///
    /// For a function `func doSomething()`, this will generate a function with a body that calls the mock's `adapt` function.
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
    
    /// Generates a variable declaration that fulfills a protocol requirement.
    ///
    /// For a variable `var value: Int { get }`, this will generate a computed property with a getter that calls the mock's `adapt` function.
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
    
    /// Generates a subscript declaration that fulfills a protocol requirement.
    ///
    /// For a subscript `subscript(index: Int) -> String`, this will generate a subscript with a getter that calls the mock's `adapt` function.
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

    /// Generates the body of a function requirement.
    ///
    /// This function generates a `CodeBlockSyntax` that contains the appropriate `adapt` call based on the function's effects (async, throws).
    ///
    /// For a function `func doSomething() throws -> Int`, this will generate:
    /// ```swift
    /// { try adaptThrowing(super.doSomething) }
    /// ```
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
    
    /// Generates the base function call for a function requirement body.
    ///
    /// This function creates a `FunctionCallExprSyntax` that calls the appropriate `adapt` function.
    private static func baseFunctionRequirementBody(_ functionDecl: FunctionDeclSyntax) -> FunctionCallExprSyntax {
        let effectType = getFunctionEffectType(functionDecl)
        return adaptCall(
            effectType: effectType,
            requirementName: functionDecl.name,
            parameters: functionDecl.signature.parameterClause.parameters
                .map({ $0.secondName ?? $0.firstName})
        )
    }

    /// Creates a call to the appropriate `adapt` function.
    ///
    /// This function constructs a `FunctionCallExprSyntax` for `adapt`, `adaptThrowing`, etc., based on the `EffectType`.
    ///
    /// For a function `myMethod(param1: Int)` with `effectType: .none`, this will generate:
    /// ```swift
    /// adapt(super.myMethod, param1)
    /// ```
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

