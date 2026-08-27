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
    static func makeConformanceRequirements(
        for protocolDecl: ProtocolDeclSyntax,
        spyAccess: SpyAccess = .inherited
    ) -> [DeclSyntax] {
        var declarations = [DeclSyntax]()
        for member in protocolDecl.memberBlock.members {
            if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
                declarations.append(DeclSyntax(functionRequirement(functionDecl, spyAccess: spyAccess)))
            } else if let variableDecl = member.decl.as(VariableDeclSyntax.self) {
                declarations.append(DeclSyntax(variableRequirement(variableDecl, spyAccess: spyAccess)))
            } else if let subscriptDecl = member.decl.as(SubscriptDeclSyntax.self) {
                declarations.append(DeclSyntax(subscriptRequirement(subscriptDecl, spyAccess: spyAccess)))
            } else if let initDecl = member.decl.as(InitializerDeclSyntax.self) {
                declarations.append(DeclSyntax(initializerRequirement(initDecl, spyAccess: spyAccess)))

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
    ///
    /// Under `.composition` the body is `fatalError(...)` instead of empty.
    /// A composed mock inherits the superclass its protocol constrains it to,
    /// and Swift requires every designated initializer to chain to `super.init`:
    ///
    /// ```
    /// error: 'super.init' isn't called on all paths before returning from initializer
    /// ```
    ///
    /// The macro cannot synthesize that call — it never sees the superclass, so
    /// it cannot know which initializers exist or what to pass them. Emitting
    /// `super.init()` is not a fix either: it fails the same way whenever the
    /// superclass has no zero-arg initializer. A `Never`-returning call
    /// satisfies the chaining rule without naming any initializer, and costs
    /// nothing in practice — the generated `init` exists only to satisfy the
    /// protocol requirement, and tests construct mocks through the zero-arg
    /// `init()` the mock gets for free.
    ///
    /// The inheriting strategy keeps the empty body: `Mock` always has a
    /// zero-arg initializer, so Swift inserts the `super.init()` call
    /// implicitly and the requirement compiles as-is.
    static func initializerRequirement(
        _ initDecl: InitializerDeclSyntax,
        spyAccess: SpyAccess = .inherited
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
                if case .composed = spyAccess {
                    ExprSyntax(#"fatalError("init(...) is not implemented on generated mocks")"#)
                }
            }
        )
    }

    /// Generates a function declaration that fulfills a protocol requirement.
    ///
    /// For a function `func doSomething()`, this will generate a function with a body that calls the mock's `adapt` function.
    static func functionRequirement(
        _ functionDecl: FunctionDeclSyntax,
        spyAccess: SpyAccess = .inherited
    ) -> FunctionDeclSyntax {
        return FunctionDeclSyntax(
            attributes: functionDecl.attributes,
            // Trimmed because modifiers copied from the protocol carry the
            // source's leading trivia; that stale newline and indentation would
            // otherwise survive into the generated member and misindent it.
            // `mutating`/`nonmutating` are dropped because the mock is a class.
            modifiers: functionDecl.modifiers.withoutValueTypeModifiers.trimmed,
            name: functionDecl.name,
            genericParameterClause: functionDecl.genericParameterClause,
            signature: functionDecl.signature,
            body: functionRequirementBody(functionDecl, spyAccess: spyAccess)
        )
    }
    
    /// Generates a variable declaration that fulfills a protocol requirement.
    ///
    /// For a variable `var value: Int { get }`, this will generate a computed property with a getter that calls the mock's `adapt` function.
    static func variableRequirement(
        _ variableDecl: VariableDeclSyntax,
        spyAccess: SpyAccess = .inherited
    ) -> VariableDeclSyntax {
        let isStatic = variableDecl.modifiers.contains(where: \.isStatic)
        return VariableDeclSyntax(
            attributes: variableDecl.attributes,
            modifiers: variableDecl.modifiers.trimmed,
            // Trimmed so the `var` keyword does not carry the protocol's source
            // indentation: BasicFormat infers a block's indentation by *adding*
            // the first token's existing leading trivia to the enclosing level,
            // which would double-indent the generated property.
            bindingSpecifier: variableDecl.bindingSpecifier.trimmed,
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
                                                        requirementName: .identifier(variableDecl.name.text.setterSpyName),
                                                        parameters: [ExprSyntax(TupleExprSyntax(elements: LabeledExprListSyntax())), ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("newValue")))],
                                                        spyAccess: spyAccess,
                                                        isStatic: isStatic
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
                                                parameters: [],
                                                spyAccess: spyAccess,
                                                isStatic: isStatic
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
    /// For a subscript `subscript(index: Int) -> String { get }`, this will generate a subscript with a getter that calls the mock's `adapt` function.
    /// For a settable requirement, it also generates a setter that records the write —
    /// indices followed by `newValue` — on the `set` + capitalized-parameters spy.
    static func subscriptRequirement(
        _ subscriptDecl: SubscriptDeclSyntax,
        spyAccess: SpyAccess = .inherited
    ) -> SubscriptDeclSyntax {
        let parameterNames = subscriptDecl.parameterClause.parameters.map({ ExprSyntax(DeclReferenceExprSyntax(baseName: $0.secondName ?? $0.firstName)) })
        let isStatic = subscriptDecl.modifiers.contains(where: \.isStatic)
        return SubscriptDeclSyntax(
            attributes: subscriptDecl.attributes,
            modifiers: subscriptDecl.modifiers,
            genericParameterClause: subscriptDecl.genericParameterClause,
            parameterClause: subscriptDecl.parameterClause,
            returnClause: subscriptDecl.returnClause,
            genericWhereClause: subscriptDecl.genericWhereClause,
            accessorBlock: AccessorBlockSyntax(
                accessors: .accessors(
                    AccessorDeclListSyntax {
                        // Setter
                        if subscriptDecl.hasSetter {
                            AccessorDeclSyntax(
                                accessorSpecifier: .keyword(.set),
                                bodyBuilder: {
                                    ReturnStmtSyntax(
                                        expression: adaptCall(
                                            effectType: .none,
                                            requirementName: .identifier(subscriptDecl.name.setterSpyName),
                                            parameters: parameterNames + [ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("newValue")))],
                                            spyAccess: spyAccess,
                                            isStatic: isStatic
                                        )
                                    )
                                }
                            )
                        }
                        // Getter
                        AccessorDeclSyntax(
                            accessorSpecifier: .keyword(.get),
                            bodyBuilder: {
                                ReturnStmtSyntax(
                                    expression: adaptCall(
                                        effectType: .none,
                                        requirementName: .identifier(subscriptDecl.name),
                                        parameters: parameterNames,
                                        spyAccess: spyAccess,
                                        isStatic: isStatic
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
    static func functionRequirementBody(
        _ funcDecl: FunctionDeclSyntax,
        spyAccess: SpyAccess = .inherited
    ) -> CodeBlockSyntax {
        let effectType = getFunctionEffectType(funcDecl)
        return CodeBlockSyntax {
            switch effectType {
            case .none:
                // The `return` is load-bearing for `Void`-returning members
                // under `.composition`: without a contextual result type the
                // solver cannot infer `Output` for the generic spy subscript,
                // and the compiler reports a "failed to produce diagnostic"
                // internal error rather than a usable message.
                ReturnStmtSyntax(expression: baseFunctionRequirementBody(funcDecl, spyAccess: spyAccess))
            case .asyncThrows:
                ReturnStmtSyntax(
                    expression: TryExprSyntax(
                        expression: AwaitExprSyntax(
                            expression: baseFunctionRequirementBody(funcDecl, spyAccess: spyAccess)
                        )
                    )
                )
            case .throws:
                ReturnStmtSyntax(
                    expression: TryExprSyntax(
                        expression: baseFunctionRequirementBody(funcDecl, spyAccess: spyAccess)
                    )
                )
            case .async:
                ReturnStmtSyntax(
                    expression: AwaitExprSyntax(
                        expression: baseFunctionRequirementBody(funcDecl, spyAccess: spyAccess)
                    )
                )
            }
        }
    }
    
    /// Generates the base function call for a function requirement body.
    ///
    /// This function creates a `FunctionCallExprSyntax` that calls the appropriate `adapt` function.
    private static func baseFunctionRequirementBody(
        _ functionDecl: FunctionDeclSyntax,
        spyAccess: SpyAccess = .inherited
    ) -> FunctionCallExprSyntax {
        let effectType = getFunctionEffectType(functionDecl)
        return adaptCall(
            effectType: effectType,
            requirementName: functionDecl.name,
            parameters: functionDecl.signature.parameterClause.parameters
                .map({ ExprSyntax(DeclReferenceExprSyntax(baseName: $0.secondName ?? $0.firstName)) }),
            spyAccess: spyAccess,
            isStatic: functionDecl.modifiers.contains(where: \.isStatic)
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
    private static func adaptCall(
        effectType: EffectType,
        requirementName: TokenSyntax,
        parameters: [ExprSyntax],
        spyAccess: SpyAccess = .inherited,
        isStatic: Bool = false
    ) -> FunctionCallExprSyntax {
        let adaptingName = "adapt" + (effectType.rawValue.contains("Throws") ? "Throwing" : "")
        return FunctionCallExprSyntax(
            calledExpression: spyAccess.adapterCallee(adaptingName),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
                // super.myMethodName — or mock.myMethodName when composing
                LabeledExprSyntax(
                    expression: spyAccess.spyReference(requirementName, isStatic: isStatic)
                )

                // param1, param2... — or () when the requirement has no
                // parameters, so the spy's input pack stays (Void) and matches
                // the pack spelled by the generated Interaction.
                if parameters.isEmpty {
                    LabeledExprSyntax(
                        expression: TupleExprSyntax(elements: LabeledExprListSyntax())
                    )
                } else {
                    for parameter in parameters {
                        LabeledExprSyntax(expression: parameter)
                    }
                }
            },
            rightParen: .rightParenToken()
        )
    }
}

