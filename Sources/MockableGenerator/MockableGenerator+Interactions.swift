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
        var functionNames = [String: Int]()

        for member in protocolDecl.memberBlock.members {
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                let stubFunction = processFunc(funcDecl, &functionNames)
                members.append(stubFunction)
            } else if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                let stubFunctions = processVar(varDecl)
                members.append(contentsOf: stubFunctions)
            } else if let subscriptDecl = member.decl.as(SubscriptDeclSyntax.self) {
                let stubFunction = processSubscript(subscriptDecl)
                members.append(stubFunction)
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
    private static func processFunc(_ funcDecl: FunctionDeclSyntax, _ functionNames: inout [String: Int]) -> DeclSyntax {
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
    /// func getName() -> Interaction<Void, None, String> { ... }
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

            let hasSetter = varDecl.hasSetter

            // Getter
            let getter = createGetterInteraction(
                varName: varName,
                type: type,
                modifiers: varDecl.modifiers
            )
            decls.append(DeclSyntax(getter))

            if hasSetter {
                let setter = createSetterInteraction(
                    varName: varName,
                    type: type,
                    modifiers: varDecl.modifiers
                )
                decls.append(DeclSyntax(setter))
            }
        }
        return decls
    }

    /// Processes a subscript declaration to generate an interaction function.
    ///
    /// For a subscript `subscript(index: Int) -> String`, this will generate:
    /// ```swift
    /// subscript(index: ArgMatcher<Int>) -> Interaction<Int, None, String> {
    ///     get { ... }
    /// }
    /// ```
    private static func processSubscript(_ subscriptDecl: SubscriptDeclSyntax) -> DeclSyntax {
        let subscriptDecl = SubscriptDeclSyntax(
            attributes: subscriptDecl.attributes,
            modifiers: subscriptDecl.modifiers,
            parameterClause: createArgMatcherParameters(
                subscriptDecl.parameterClause
            ),
            returnClause: createInteractionReturnType(
                inputTypes: subscriptDecl.parameterClause.parameters.map(\.type),
                outputType: subscriptDecl.returnClause.type,
                effectType: .none,
                genericParameterClause: subscriptDecl.genericParameterClause
            ),
            accessorBlock: AccessorBlockSyntax(
                accessors: .accessors(AccessorDeclListSyntax {
                    // Get
                    AccessorDeclSyntax(
                        accessorSpecifier: .keyword(.get),
                        bodyBuilder: {
                            createFunctionBody(
                                spyPropertyName: "subscript",
                                parameterNames: subscriptDecl.parameterClause.parameters
                            ).statements
                        }
                    )
                    //

                })
            )
        )

        return DeclSyntax(subscriptDecl)
    }

    /// Creates a getter interaction function for a variable.
    ///
    /// For a variable `var name: String`, this will generate:
    /// ```swift
    /// func getName() -> Interaction<Void, None, String> { ... }
    /// ```
    private static func createGetterInteraction(varName: String, type: TypeSyntax, modifiers: DeclModifierListSyntax) -> FunctionDeclSyntax {
        let interactionReturnType = createInteractionReturnType(inputTypes: [], outputType: type, effectType: .none, genericParameterClause: nil)
        let body = createFunctionBody(spyPropertyName: varName, parameterNames: [])
        return FunctionDeclSyntax(
            modifiers: modifiers.trimmed,
            name: .identifier("get\(varName.capitalized)"),
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(parameters: []),
                returnClause: interactionReturnType
            ),
            body: body
        )
    }

    /// Creates a setter interaction function for a variable.
    ///
    /// For a variable `var name: String`, this will generate:
    /// ```swift
    /// func setName(newValue: ArgMatcher<String>) -> Interaction<String, None, Void> { ... }
    /// ```
    private static func createSetterInteraction(varName: String, type: TypeSyntax, modifiers: DeclModifierListSyntax) -> FunctionDeclSyntax {
        let setterName = "set" + varName.capitalized
        let parameter = FunctionParameterSyntax(
            firstName: .identifier("newValue"),
            colon: .colonToken(trailingTrivia: .space),
            type: TypeSyntax(
                IdentifierTypeSyntax(
                    name: .identifier("ArgMatcher"),
                    genericArgumentClause: GenericArgumentClauseSyntax {
                        #if canImport(SwiftSyntax601)
                        GenericArgumentSyntax(argument: .init(type))
                        #else
                        GenericArgumentSyntax(argument: (type))
                        #endif
                    }
                )
            )
        )
        let parameterList = FunctionParameterListSyntax([parameter])
        let interactionReturnType = createInteractionReturnType(inputTypes: [type], outputType: TypeSyntax(stringLiteral: "Void"), effectType: .none, genericParameterClause: nil)
        let body = createFunctionBody(
            spyPropertyName: setterName,
            parameterNames: FunctionParameterListSyntax {
                FunctionParameterSyntax.init(
                    firstName: .identifier("newValue"),
                    type: type
                )
            }
        )

        return FunctionDeclSyntax(
            modifiers: modifiers.trimmed,
            name: .identifier(setterName),
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(parameters: parameterList),
                returnClause: interactionReturnType
            ),
            body: body
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
            genericArgs.append(GenericArgumentSyntax(argument: argType))
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
        let interactionCall = FunctionCallExprSyntax(
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

            LabeledExprSyntax(
                label: "spy",
                expression: MemberAccessExprSyntax(
                    base: SuperExprSyntax(),
                    name: .identifier(spyPropertyName)
                )
            )

        }

        return CodeBlockSyntax(statements: [CodeBlockItemSyntax(item: .expr(ExprSyntax(interactionCall)))])
    }
}
