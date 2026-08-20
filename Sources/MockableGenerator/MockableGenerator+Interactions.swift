//
//  SpyGenerator.swift
//  Mockable
//
//  Created by Daniel Cardona on 7/07/25.
//
import SwiftSyntax
import SwiftSyntaxBuilder

public enum EffectType: String {
    case asyncThrows = "AsyncThrows"
    case `throws` = "Throws"
    case `async` = "Async"
    case none = "None"
}

public extension MockableGenerator {
    /// Processes a protocol declaration to generate interaction members.
    ///
    /// This function takes a `ProtocolDeclSyntax` and generates a corresponding spy struct that conforms to the protocol.
    /// The generated struct will have a `Spy` property for each function in the protocol, and a stubbing method that uses `ArgMatcher`s.
    ///
    /// For example, given the following protocol:
    /// ```swift
    /// protocol MyService {
    ///     func doSomething(with value: String) -> Int
    /// }
    /// ```
    /// This function will generate the following members:
    /// ```swift
    /// func doSomething(with value: ArgMatcher<String>) -> Interaction<String, None, Int> {
    ///     Interaction(value, spy: doSomething)
    /// }
    /// ```
    static func makeInteractions(protocolDecl: ProtocolDeclSyntax) -> [DeclSyntax] {
        var members = [DeclSyntax]()

        for member in protocolDecl.memberBlock.members {
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                let stubFunction = processFunc(funcDecl)
                members.append(stubFunction)
            } else if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                let stubFunctions = processVar(varDecl)
                members.append(contentsOf: stubFunctions)
            } else if let subscriptDecl = member.decl.as(SubscriptDeclSyntax.self) {
                members.append(contentsOf: processSubscript(subscriptDecl))
            }
        }

        return members
    }

    /// Processes a function declaration to generate a spy property and a stubbing function.
    ///
    /// For example, for a function `func doSomething(with value: String) -> Int`, this will generate:
    /// ```swift
    /// func doSomething(with value: ArgMatcher<String>) -> Interaction<String, None, Int> {
    ///     Interaction(value, spy: super.doSomething)
    /// }
    /// ```
    private static func processFunc(_ funcDecl: FunctionDeclSyntax) -> DeclSyntax {
        let funcName = funcDecl.name.text
        let spyPropertyName = funcDecl.name.text

        let stubFunction = createStubFunction(
            name: funcName,
            spyPropertyName: spyPropertyName,
            funcDecl: funcDecl,
            genericParameterClause: funcDecl.genericParameterClause,
            genericWhereClause: funcDecl.genericWhereClause
        )

        return DeclSyntax(stubFunction)
    }

    /// Processes a variable declaration to generate getter and setter interaction functions.
    ///
    /// For a variable `var name: String { get set }`, this will generate:
    /// ```swift
    /// func name(_ void: Void) -> Interaction<Void, None, String> { ... }
    /// func setName(newValue: ArgMatcher<String>) -> Interaction<String, None, Void> { ... }
    /// ```
    private static func processVar(_ varDecl: VariableDeclSyntax) -> [DeclSyntax] {
        var decls = [DeclSyntax]()
        for binding in varDecl.bindings {
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }
            let varName = pattern.identifier.text
            guard let type = binding.typeAnnotation?.type else {
                continue
            }

            if varDecl.hasSetter {
                decls.append(DeclSyntax(createSettableGetterInteraction(
                    varName: varName,
                    type: type,
                    modifiers: varDecl.modifiers
                )))
            } else {
                // Getter
                let getter = createGetterInteraction(
                    varName: varName,
                    type: type,
                    modifiers: varDecl.modifiers
                )
                decls.append(DeclSyntax(getter))
            }
        }
        return decls
    }

    /// Processes a subscript declaration to generate the interaction declaration.
    ///
    /// Get-only requirements generate an `Interaction` subscript; settable
    /// requirements generate a `SettableInteraction` subscript exposing reads
    /// (`when`/`verify`) and writes (`assigned:`) through one surface.
    private static func processSubscript(_ subscriptDecl: SubscriptDeclSyntax) -> [DeclSyntax] {
        if subscriptDecl.hasSetter {
            return [DeclSyntax(subscriptSettableInteraction(subscriptDecl))]
        }
        return [DeclSyntax(subscriptGetterInteraction(subscriptDecl))]
    }

    /// Creates a getter interaction subscript mirroring the requirement's indices.
    ///
    /// For a subscript `subscript(index: Int) -> String`, this will generate:
    /// ```swift
    /// subscript(index: ArgMatcher<Int>) -> Interaction<Int, None, String> {
    ///     get { Interaction(index, spy: super.index) }
    /// }
    /// ```
    private static func subscriptGetterInteraction(_ subscriptDecl: SubscriptDeclSyntax) -> SubscriptDeclSyntax {
        let subscriptDecl = SubscriptDeclSyntax(
            attributes: subscriptDecl.attributes,
            modifiers: subscriptDecl.modifiers,
            genericParameterClause: subscriptDecl.genericParameterClause,
            parameterClause: createArgMatcherParameters(
                subscriptDecl.parameterClause
            ),
            returnClause: createInteractionReturnType(
                inputTypes: subscriptDecl.parameterClause.parameters.map(\.type),
                outputType: subscriptDecl.returnClause.type,
                effectType: .none,
                genericParameterClause: subscriptDecl.genericParameterClause
            ),
            genericWhereClause: subscriptDecl.genericWhereClause,
            accessorBlock: AccessorBlockSyntax(
                accessors: .accessors(AccessorDeclListSyntax {
                    // Get
                    AccessorDeclSyntax(
                        accessorSpecifier: .keyword(.get),
                        bodyBuilder: {
                            createFunctionBody(
                                spyPropertyName: subscriptDecl.name,
                                parameterNames: subscriptDecl.parameterClause.parameters
                            ).statements
                        }
                    )
                })
            )
        )

        return subscriptDecl
    }

    /// Creates a settable interaction subscript exposing both directions.
    ///
    /// For a settable subscript `subscript(index: Int) -> String { get set }`, this will generate:
    /// ```swift
    /// subscript(index: ArgMatcher<Int>) -> SettableInteraction<Int, String> {
    ///     get {
    ///         SettableInteraction(
    ///             get: Interaction(index, spy: super.index),
    ///             setInteraction: { __mockableNewValue in
    ///                 Interaction(index, __mockableNewValue, spy: super.setIndex)
    ///             }
    ///         )
    ///     }
    /// }
    /// ```
    ///
    /// Reads record on the `subscript` spy, writes on the `setSubscript` spy with
    /// the written value as a trailing argument.
    private static func subscriptSettableInteraction(_ subscriptDecl: SubscriptDeclSyntax) -> SubscriptDeclSyntax {
        SubscriptDeclSyntax(
            attributes: subscriptDecl.attributes,
            modifiers: subscriptDecl.modifiers,
            genericParameterClause: subscriptDecl.genericParameterClause,
            parameterClause: createArgMatcherParameters(
                subscriptDecl.parameterClause
            ),
            returnClause: createSettableInteractionReturnType(
                inputTypes: subscriptDecl.parameterClause.parameters.map(\.type),
                outputType: subscriptDecl.returnClause.type,
                effectType: .none
            ),
            genericWhereClause: subscriptDecl.genericWhereClause,
            accessorBlock: AccessorBlockSyntax(
                accessors: .accessors(AccessorDeclListSyntax {
                    AccessorDeclSyntax(
                        accessorSpecifier: .keyword(.get),
                        bodyBuilder: {
                            createSettableFunctionBody(
                                getterSpyName: subscriptDecl.name,
                                setterSpyName: subscriptDecl.name.setterSpyName,
                                parameterNames: subscriptDecl.parameterClause.parameters
                            ).statements
                        }
                    )
                })
            )
        )
    }

    /// Creates a return type for a settable interaction subscript.
    ///
    /// For input types `[Int]`, output type `String`, and effect `None`, this will generate:
    /// ```swift
    /// -> SettableInteraction<Int, None, String>
    /// ```
    private static func createSettableInteractionReturnType(inputTypes: [TypeSyntax], outputType: TypeSyntax, effectType: EffectType) -> ReturnClauseSyntax {
        var genericArgs = [GenericArgumentSyntax]()
        for inputType in inputTypes {
            #if canImport(SwiftSyntax601)
            genericArgs.append(GenericArgumentSyntax(argument: .init(removeAttributes(inputType))))
            #else
            genericArgs.append(GenericArgumentSyntax(argument: removeAttributes(inputType)))
            #endif
        }
        #if canImport(SwiftSyntax601)
        genericArgs.append(GenericArgumentSyntax(argument: .init(TypeSyntax(stringLiteral: effectType.rawValue))))
        genericArgs.append(GenericArgumentSyntax(argument: .init(outputType)))
        #else
        genericArgs.append(GenericArgumentSyntax(argument: TypeSyntax(stringLiteral: effectType.rawValue)))
        genericArgs.append(GenericArgumentSyntax(argument: outputType))
        #endif

        let genericStubType = IdentifierTypeSyntax(
            name: .identifier("SettableInteraction"),
            genericArgumentClause: GenericArgumentClauseSyntax(
                leftAngle: .leftAngleToken(),
                arguments: GenericArgumentListSyntax(
                    genericArgs.enumerated().map { (index, arg) in
                        GenericArgumentSyntax(
                            argument: arg.argument,
                            trailingComma: index == genericArgs.count - 1 ? nil : .commaToken()
                        )
                    }
                ),
                rightAngle: .rightAngleToken()
            )
        )

        return ReturnClauseSyntax(
            arrow: .arrowToken(leadingTrivia: .space, trailingTrivia: .space),
            type: TypeSyntax(genericStubType)
        )
    }

    /// Creates the body of a settable interaction member, wiring both spies.
    ///
    /// For `getterSpyName: "index"`, `setterSpyName: "setIndex"` and
    /// parameters `[index]`, this will generate:
    /// ```swift
    /// SettableInteraction(
    ///     get: Interaction(index, spy: super.index),
    ///     setInteraction: { __mockableNewValue in
    ///         Interaction(index, __mockableNewValue, spy: super.setIndex)
    ///     }
    /// )
    /// ```
    ///
    /// Each argument goes on its own line with explicit trivia: the expansion is
    /// user-facing (it appears in macro-expansion diffs and generated sources),
    /// and SwiftSyntax does not re-indent nested nodes on its own — without this
    /// the call collapses onto one line and the closure body drifts rightward.
    ///
    /// `newValue` is appended after the read arguments so the write pack is the
    /// read pack plus the written value. Empty parameter lists pass `.any` for
    /// the read's `(Void)` pack, matching `createFunctionBody`.
    private static func createSettableFunctionBody(
        getterSpyName: String,
        setterSpyName: String,
        parameterNames: FunctionParameterListSyntax
    ) -> CodeBlockSyntax {
        // Relative to the statement's own column: SwiftSyntax supplies the
        // enclosing context's indentation when the body is placed, so these
        // offsets must not restate it. That keeps one builder correct at both
        // nesting depths — a variable's function body and a subscript's `get`.
        let indent = { (level: Int) in Trivia.spaces(4 * level) }
        let getterCall = interactionCall(
            spyPropertyName: getterSpyName,
            parameterNames: parameterNames
        )
        let setterCall = interactionCall(
            spyPropertyName: setterSpyName,
            parameterNames: parameterNames,
            newValueName: writtenValueIdentifier
        )
        // { newValue in\n<indent+2>Interaction(…)\n<indent+1>}
        let setClosure = ClosureExprSyntax(
            leftBrace: .leftBraceToken(),
            signature: ClosureSignatureSyntax(
                parameterClause: .simpleInput(ClosureShorthandParameterListSyntax {
                    ClosureShorthandParameterSyntax(name: .identifier(writtenValueIdentifier))
                }),
                inKeyword: .keyword(.in)
            ),
            statements: CodeBlockItemListSyntax([
                CodeBlockItemSyntax(
                    leadingTrivia: .newline + indent(2),
                    item: .expr(ExprSyntax(setterCall))
                )
            ]),
            rightBrace: .rightBraceToken(leadingTrivia: .newline + indent(1))
        )
        // SettableInteraction(\n<indent+1>get: …,\n<indent+1>setInteraction: …\n<indent>)
        let wrapperCall = FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("SettableInteraction")),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
                LabeledExprSyntax(
                    leadingTrivia: .newline + indent(1),
                    label: .identifier("get"),
                    colon: .colonToken(trailingTrivia: .space),
                    expression: getterCall,
                    trailingComma: .commaToken()
                )
                LabeledExprSyntax(
                    leadingTrivia: .newline + indent(1),
                    label: .identifier("setInteraction"),
                    colon: .colonToken(trailingTrivia: .space),
                    expression: setClosure
                )
            },
            rightParen: .rightParenToken(leadingTrivia: .newline + indent(0))
        )

        return CodeBlockSyntax(statements: [CodeBlockItemSyntax(item: .expr(ExprSyntax(wrapperCall)))])
    }

    /// Creates a getter interaction function for a variable.
    ///
    /// For a variable `var name: String`, this will generate:
    /// ```swift
    /// func name(_ void: Void) -> Interaction<Void, None, String> { ... }
    /// ```
    ///
    /// The `Void` parameter is load-bearing, not cosmetic:
    /// - A niladic `func name()` alongside the conformance's `var name` property is an
    ///   `invalid redeclaration` — the property's getter accessor already occupies the
    ///   `name()` selector.
    /// - The unapplied member reference `mock.name` then has exactly the type
    ///   `(Void) -> Interaction<Void, None, T>`, which is what the `when`/`verify`
    ///   overloads taking `(()) -> Interaction<repeat each Input, Eff, Output>` infer
    ///   their input pack from, so `when(mock.name)` and `verify(mock.name)` resolve.
    /// - It keeps the spy's input pack at `(Void)` — the same pack the conformance's
    ///   `adapt(super.name, ())` records on.
    private static func createGetterInteraction(varName: String, type: TypeSyntax, modifiers: DeclModifierListSyntax) -> FunctionDeclSyntax {
        let interactionReturnType = createInteractionReturnType(inputTypes: [], outputType: type, effectType: .none, genericParameterClause: nil)
        let body = createFunctionBody(spyPropertyName: varName, parameterNames: [])
        let voidParameter = FunctionParameterSyntax(
            firstName: .wildcardToken(),
            secondName: .identifier("void"),
            colon: .colonToken(trailingTrivia: .space),
            type: IdentifierTypeSyntax(name: .identifier("Void"))
        )
        return FunctionDeclSyntax(
            modifiers: modifiers.trimmed,
            name: .identifier(varName),
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    parameters: FunctionParameterListSyntax([voidParameter])
                ),
                returnClause: interactionReturnType
            ),
            body: body
        )
    }

    /// Creates a settable interaction function for a variable.
    ///
    /// For a settable variable `var value: Int { get set }`, this will generate:
    /// ```swift
    /// func value(_ void: Void) -> SettableInteraction<Void, Int> {
    ///     SettableInteraction(
    ///         get: Interaction(.any, spy: super.value),
    ///         setInteraction: { __mockableNewValue in
    ///             Interaction(.any, __mockableNewValue, spy: super.setValue)
    ///         }
    ///     )
    /// }
    /// ```
    ///
    /// The read pack is `(Void)`, matching the conformance getter's
    /// `adapt(super.value, ())`; the write pack is `(Void, newValue)`, matching
    /// the conformance setter's `adapt(super.setValue, (), __mockableNewValue)` — writes
    /// record the read pack plus the written value.
    private static func createSettableGetterInteraction(varName: String, type: TypeSyntax, modifiers: DeclModifierListSyntax) -> FunctionDeclSyntax {
        let voidParameter = FunctionParameterSyntax(
            firstName: .wildcardToken(),
            secondName: .identifier("void"),
            colon: .colonToken(trailingTrivia: .space),
            type: IdentifierTypeSyntax(name: .identifier("Void"))
        )
        return FunctionDeclSyntax(
            modifiers: modifiers.trimmed,
            name: .identifier(varName),
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    parameters: FunctionParameterListSyntax([voidParameter])
                ),
                returnClause: createSettableInteractionReturnType(
                    inputTypes: [TypeSyntax(stringLiteral: "Void")],
                    outputType: type,
                    effectType: .none
                )
            ),
            body: createSettableFunctionBody(
                getterSpyName: varName,
                setterSpyName: varName.setterSpyName,
                parameterNames: FunctionParameterListSyntax([])
            )
        )
    }

    /// Extracts the parameter types, internal names, and external labels from a function declaration.
    ///
    /// For example, for `func doSomething(with value: String)`, this will return:
    /// `inputTypes: [String]`, `parameterNames: [value]`, `parameterLabels: [with]`
    private static func getFunctionParameters(_ funcDecl: FunctionDeclSyntax) -> ([TypeSyntax], [TokenSyntax], [TokenSyntax?]) {
        let parameters = funcDecl.signature.parameterClause.parameters
        let inputTypes = parameters.map { parameter in
            if parameter.ellipsis != nil {
                let arrayType = ArrayTypeSyntax(element: parameter.type)
                return TypeSyntax(arrayType)
            }
            return parameter.type
        }
        let parameterNames = parameters.map { $0.secondName ?? $0.firstName }
        let parameterLabels = parameters.map { $0.firstName }
        return (inputTypes, parameterNames, parameterLabels)
    }

    /// Extracts the return type from a function declaration.
    ///
    /// For example, for `-> Int`, this will return `Int`.
    /// If no return type is specified, it returns `Void`.
    private static func getFunctionReturnType(_ funcDecl: FunctionDeclSyntax) -> TypeSyntax {
        return funcDecl.signature.returnClause?.type ?? TypeSyntax(stringLiteral: "Void")
    }

    /// Extracts the effect type (throws, async, etc.) from a function declaration.
    ///
    /// For example, for `async throws -> Int`, this will return `AsyncThrows`.
    static func getFunctionEffectType(_ funcDecl: FunctionDeclSyntax) -> EffectType {
        let effects = funcDecl.signature.effectSpecifiers
        if effects?.throwsClause != nil && effects?.asyncSpecifier != nil {
            return .asyncThrows
        } else if effects?.throwsClause != nil {
            return .throws
        } else if effects?.asyncSpecifier != nil {
            return .async
        } else {
            return .none
        }
    }

    /// Creates a stubbing function declaration.
    ///
    /// For example, for a function `doSomething(with value: String) -> Int`, this will generate:
    /// ```swift
    /// func doSomething(with value: ArgMatcher<String>) -> Interaction<String, None, Int> {
    ///     Interaction(value, spy: super.doSomething)
    /// }
    /// ```
    private static func createStubFunction(
        name: String,
        spyPropertyName: String,
        funcDecl: FunctionDeclSyntax,
        genericParameterClause: GenericParameterClauseSyntax?,
        genericWhereClause: GenericWhereClauseSyntax?
    ) -> FunctionDeclSyntax {

        let (inputTypes, _, _) = getFunctionParameters(funcDecl)
        let outputType = getFunctionReturnType(funcDecl)
        let effectType = getFunctionEffectType(funcDecl)

        let functionParamClause = createArgMatcherParameters(
            funcDecl.signature.parameterClause
        )
        let returnType = createInteractionReturnType(inputTypes: inputTypes, outputType: outputType, effectType: effectType, genericParameterClause: genericParameterClause)
        let body = createFunctionBody(
            spyPropertyName: spyPropertyName,
            parameterNames: funcDecl.signature.parameterClause.parameters
        )

        return FunctionDeclSyntax(
            modifiers: funcDecl.modifiers.trimmed,
            name: TokenSyntax.identifier(name),
            genericParameterClause: genericParameterClause,
            signature: FunctionSignatureSyntax(
                parameterClause: functionParamClause,
                returnClause: returnType
            ),
            genericWhereClause: genericWhereClause,
            body: body
        )
    }

    /// Creates a parameter list for a stubbing function.
    ///
    /// For example, for a function `doSomething(with value: String)`, this will generate:
    /// ```swift
    /// (with value: ArgMatcher<String>)
    /// ```
    private static func createArgMatcherParameters(_ parameterClause: FunctionParameterClauseSyntax) -> FunctionParameterClauseSyntax {
        let paramList = FunctionParameterListSyntax {
            for parameter in parameterClause.parameters {
                FunctionParameterSyntax(
                    firstName: parameter.firstName,
                    secondName: parameter.secondName,
                    colon: .colonToken(trailingTrivia: .space),
                    type: TypeSyntax(
                        IdentifierTypeSyntax(
                            name: .identifier("ArgMatcher"),
                            genericArgumentClause: GenericArgumentClauseSyntax {

                                #if canImport(SwiftSyntax601)
                                GenericArgumentSyntax(
                                    argument: .init(removeAttributes(parameter.type))
                                )
                                #else
                                GenericArgumentSyntax(
                                    argument: removeAttributes(parameter.type)
                                )
                                #endif
                            }
                        )
                    ),
                    ellipsis: parameter.ellipsis
                )
            }
        }

        return FunctionParameterClauseSyntax(parameters: paramList)

    }

    private static func removeAttributes(_ type: TypeSyntaxProtocol) -> TypeSyntax {
        guard let attributedType = type.as(AttributedTypeSyntax.self) else {
            return TypeSyntax(fromProtocol: type)
        }

        return attributedType.baseType
    }

    /// Creates a return type for a stubbing function.
    ///
    /// For example, for a function that `throws` and  returns an `Int`, this will generate:
    /// ```swift
    /// -> Interaction<String, Throws, Int>
    /// ```
    private static func createInteractionReturnType(inputTypes: [TypeSyntax], outputType: TypeSyntax, effectType: EffectType, genericParameterClause: GenericParameterClauseSyntax?) -> ReturnClauseSyntax {
        var genericArgs = [GenericArgumentSyntax]()
        // Map generic parameter names to their first type constraint
        var genericParameterConstraints: [String: TypeSyntax] = [:]
        if let genericParams = genericParameterClause?.parameters {
            for param in genericParams {
                if let constrainedType = param.inheritedType {
                    genericParameterConstraints[param.name.text] = constrainedType
                }
            }
        }

        for inputType in inputTypes {
            let argType = inputType
            #if canImport(SwiftSyntax601)
            genericArgs.append(GenericArgumentSyntax(argument: .init(removeAttributes(argType))))
            #else
            genericArgs.append(GenericArgumentSyntax(argument: removeAttributes(argType)))
            #endif
        }

        if inputTypes.isEmpty {
            #if canImport(SwiftSyntax601)
            genericArgs.append(GenericArgumentSyntax(argument: .init(TypeSyntax(stringLiteral: "Void"))))
            #else
            genericArgs.append(GenericArgumentSyntax(argument: TypeSyntax(stringLiteral: "Void")))
            #endif
        }

        #if canImport(SwiftSyntax601)
        genericArgs.append(GenericArgumentSyntax(argument: .init(TypeSyntax(stringLiteral: effectType.rawValue))))
        genericArgs.append(GenericArgumentSyntax(argument: .init(outputType)))
        #else
        genericArgs.append(GenericArgumentSyntax(argument: TypeSyntax(stringLiteral: effectType.rawValue)))
        genericArgs.append(GenericArgumentSyntax(argument: outputType))
        #endif

        let genericStubType = IdentifierTypeSyntax(
            name: .identifier("Interaction"),
            genericArgumentClause: GenericArgumentClauseSyntax(
                leftAngle: .leftAngleToken(),
                arguments: GenericArgumentListSyntax(
                    genericArgs.enumerated().map { (index, arg) in
                        GenericArgumentSyntax(
                            argument: arg.argument,
                            trailingComma: index == genericArgs.count - 1 ? nil : .commaToken()
                        )
                    }
                ),
                rightAngle: .rightAngleToken()
            )
        )

        return ReturnClauseSyntax(
            arrow: .arrowToken(leadingTrivia: .space, trailingTrivia: .space),
            type: TypeSyntax(genericStubType)
        )
    }

    /// Creates a function body for a stubbing function.
    ///
    /// For example, for a function `doSomething(with value: String)`, this will generate:
    /// ```swift
    /// {
    ///     Interaction(value, spy: doSomething)
    /// }
    /// ```
    private static func createFunctionBody(spyPropertyName: String, parameterNames: FunctionParameterListSyntax) -> CodeBlockSyntax {
        return CodeBlockSyntax(statements: [CodeBlockItemSyntax(item: .expr(ExprSyntax(interactionCall(spyPropertyName: spyPropertyName, parameterNames: parameterNames))))])
    }

    /// Creates an `Interaction(…, spy: super.<spy>)` call expression.
    ///
    /// Arguments are the read parameters (`.any` for an empty read pack, `.variadic(…)`
    /// for variadic parameters), optionally followed by `newValueName` so the write
    /// pack is the read pack plus the written value.
    private static func interactionCall(
        spyPropertyName: String,
        parameterNames: FunctionParameterListSyntax,
        newValueName: String? = nil
    ) -> FunctionCallExprSyntax {
        FunctionCallExprSyntax(
            callee: DeclReferenceExprSyntax(baseName: .identifier("Interaction"))
        ) {
            for parameter in parameterNames {
                if parameter.ellipsis != nil {
                    LabeledExprSyntax(
                        expression: FunctionCallExprSyntax(
                            calledExpression: MemberAccessExprSyntax(
                                period: .periodToken(),
                                name: .identifier("variadic")
                            ),
                            leftParen: .leftParenToken(),
                            arguments: LabeledExprListSyntax {
                                LabeledExprSyntax(
                                    expression: DeclReferenceExprSyntax(baseName: parameter.secondName ?? parameter.firstName)
                                )
                            },
                            rightParen: .rightParenToken()
                        )
                    )
                } else {
                    LabeledExprSyntax(
                        expression: DeclReferenceExprSyntax(baseName: parameter.secondName ?? parameter.firstName)
                    )
                }
            }

            if parameterNames.isEmpty {
                LabeledExprSyntax(
                    expression: DeclReferenceExprSyntax(baseName: .identifier(".any"))
                )
            }

            if let newValueName {
                LabeledExprSyntax(
                    expression: DeclReferenceExprSyntax(baseName: .identifier(newValueName))
                )
            }

            LabeledExprSyntax(
                label: "spy",
                expression: MemberAccessExprSyntax(
                    base: SuperExprSyntax(),
                    name: .identifier(spyPropertyName)
                )
            )

        }
    }
}
