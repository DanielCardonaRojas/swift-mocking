//
//  SpyGenerator.swift
//  Mockable
//
//  Created by Daniel Cardona on 7/07/25.
//
import SwiftSyntax
import SwiftSyntaxBuilder

public extension MockableGenerator {
    /// Processes a protocol declaration to generate a spy struct.
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
    /// This function will generate the following struct:
    /// ```swift
    /// struct Spying {
    ///     let doSomething = Spy<String, None, Int>()
    ///     func doSomething(with value: ArgMatcher<String>) -> Interaction<String, None, Int> {
    ///         Interaction(value, spy: doSomething)
    ///     }
    /// }
    /// ```
    static func makeInteractions(protocolDecl: ProtocolDeclSyntax) throws -> [DeclSyntax] {
        var members = [DeclSyntax]()
        var functionNames = [String: Int]()

        for member in protocolDecl.memberBlock.members {
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                let stubFunction = try processFunc(funcDecl, &functionNames)
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
    private static func processFunc(_ funcDecl: FunctionDeclSyntax, _ functionNames: inout [String: Int]) throws -> DeclSyntax {
        let funcName = funcDecl.name.text
        let spyPropertyName = MockableGenerator.spyPropertyName(for: funcDecl, functionNames: &functionNames)

        let stubFunction = try createStubFunction(
            name: funcName,
            spyPropertyName: spyPropertyName,
            funcDecl: funcDecl,
            genericParameterClause: funcDecl.genericParameterClause,
            genericWhereClause: funcDecl.genericWhereClause
        )

        return DeclSyntax(stubFunction)
    }

    /// Extracts the parameter types, internal names, and external labels from a function declaration.
    ///
    /// For example, for `func doSomething(with value: String)`, this will return:
    /// `inputTypes: [String]`, `parameterNames: [value]`, `parameterLabels: [with]`
    private static func getFunctionParameters(_ funcDecl: FunctionDeclSyntax) -> ([TypeSyntax], [TokenSyntax], [TokenSyntax?]) {
        let parameters = funcDecl.signature.parameterClause.parameters
        let inputTypes = parameters.map { $0.type }
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
    static func getFunctionEffectType(_ funcDecl: FunctionDeclSyntax) -> String {
        let effects = funcDecl.signature.effectSpecifiers
        if effects?.throwsClause != nil && effects?.asyncSpecifier != nil {
            return "AsyncThrows"
        } else if effects?.throwsClause != nil {
            return "Throws"
        } else if effects?.asyncSpecifier != nil {
            return "Async"
        } else {
            return "None"
        }
    }

    /// Creates a `Spy` property declaration.
    ///
    /// For example, for a function `doSomething(with value: String) -> Int`, this will generate:
    /// ```swift
    /// let doSomething = Spy<String, None, Int>()
    /// ```
    private static func createSpyProperty(name: String, inputTypes: [TypeSyntax], outputType: TypeSyntax, effectType: String) throws -> VariableDeclSyntax {
        var genericArgs = [GenericArgumentSyntax]()
        for inputType in inputTypes {
            genericArgs.append(GenericArgumentSyntax(argument: inputType))
        }
        genericArgs.append(GenericArgumentSyntax(argument: TypeSyntax(stringLiteral: effectType)))
        genericArgs.append(GenericArgumentSyntax(argument: outputType))

        let genericSpy = GenericSpecializationExprSyntax(
            expression: DeclReferenceExprSyntax(baseName: .identifier("Spy")),
            genericArgumentClause: GenericArgumentClauseSyntax(
                leftAngle: .leftAngleToken(),
                arguments: GenericArgumentListSyntax(
                    genericArgs.enumerated().map { (index, arg) in
                        if index < genericArgs.count - 1 {
                            return arg.with(\.trailingComma, .commaToken())
                        }
                        return arg
                    }
                ),
                rightAngle: .rightAngleToken()
            )
        )

        let initializer = InitializerClauseSyntax(value: FunctionCallExprSyntax(callee: genericSpy) { LabeledExprListSyntax() })
        let binding = PatternBindingSyntax(pattern: IdentifierPatternSyntax(identifier: .identifier(name)), initializer: initializer)
        return VariableDeclSyntax(
            bindingSpecifier: .keyword(.let, trailingTrivia: .space),
            bindings: [binding]
        )
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
    ) throws -> FunctionDeclSyntax {

        let (inputTypes, parameterNames, parameterLabels) = getFunctionParameters(funcDecl)
        let outputType = getFunctionReturnType(funcDecl)
        let effectType = getFunctionEffectType(funcDecl)

        let parameterList = createParameterList(inputTypes: inputTypes, parameterNames: parameterNames, parameterLabels: parameterLabels, genericParameterClause: genericParameterClause)
        let returnType = createInteractionReturnType(inputTypes: inputTypes, outputType: outputType, effectType: effectType, genericParameterClause: genericParameterClause)
        let body = createFunctionBody(spyPropertyName: spyPropertyName, parameterNames: parameterNames)

        return FunctionDeclSyntax(
            modifiers: funcDecl.modifiers.trimmed,
            name: TokenSyntax.identifier(name),
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax { parameterList },
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
    private static func createParameterList(inputTypes: [TypeSyntax], parameterNames: [TokenSyntax], parameterLabels: [TokenSyntax?], genericParameterClause: GenericParameterClauseSyntax?) -> FunctionParameterListSyntax {
        var parameters = [FunctionParameterSyntax]()
        // Map generic parameter names to their first type constraint
        var genericParameterConstraints: [String: TypeSyntax] = [:]
        if let genericParams = genericParameterClause?.parameters {
            for param in genericParams {
                if let constrainedType = param.inheritedType {
                    genericParameterConstraints[param.name.text] = constrainedType
                }
            }
        }

        for (index, type) in inputTypes.enumerated() {
            let parameterName = parameterNames[index]
            let parameterLabel = parameterLabels[index]

            let secondName: TokenSyntax?
            if parameterLabel?.text == "_" {
                if parameterName.text != "_" { // External is '_', internal is not '_'
                    secondName = parameterName
                } else { // Both are '_'
                    secondName = nil
                }
            } else if parameterLabel?.text == parameterName.text { // External and internal are the same
                secondName = nil
            } else { // External and internal are different, or only external name exists
                secondName = parameterName
            }

            let argMatcherType: TypeSyntax
            if let identifierType = type.as(IdentifierTypeSyntax.self),
               let constraint = genericParameterConstraints[identifierType.name.text] {
                // This is a generic parameter with a constraint, use 'any Constraint'
                argMatcherType = TypeSyntax(
                    SomeOrAnyTypeSyntax(
                        someOrAnySpecifier: .keyword(.any),
                        constraint: constraint
                    )
                )
            } else {
                // Not a generic parameter or no constraint, use the original type
                argMatcherType = type
            }

            let param = FunctionParameterSyntax(
                firstName: parameterLabel ?? .wildcardToken(),
                secondName: secondName,
                colon: .colonToken(trailingTrivia: .space),
                type: TypeSyntax(
                    IdentifierTypeSyntax(
                        name: .identifier("ArgMatcher"),
                        genericArgumentClause: GenericArgumentClauseSyntax { GenericArgumentSyntax(argument: argMatcherType) }
                    )
                )
            )
            parameters.append(param)
        }
        return FunctionParameterListSyntax(parameters)
    }

    /// Creates a return type for a stubbing function.
    ///
    /// For example, for a function that returns `Int`, this will generate:
    /// ```swift
    /// -> Interaction<String, None, Int>
    /// ```
    private static func createInteractionReturnType(inputTypes: [TypeSyntax], outputType: TypeSyntax, effectType: String, genericParameterClause: GenericParameterClauseSyntax?) -> ReturnClauseSyntax {
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
            let argType: TypeSyntax
            if let identifierType = inputType.as(IdentifierTypeSyntax.self),
               let constraint = genericParameterConstraints[identifierType.name.text] {
                // This is a generic parameter with a constraint, use 'any Constraint'
                argType = TypeSyntax(
                    SomeOrAnyTypeSyntax(
                        someOrAnySpecifier: .keyword(.any),
                        constraint: constraint
                    )
                )
            } else {
                // Not a generic parameter or no constraint, use the original type
                argType = inputType
            }
            genericArgs.append(GenericArgumentSyntax(argument: argType))
        }
        genericArgs.append(GenericArgumentSyntax(argument: TypeSyntax(stringLiteral: effectType)))
        genericArgs.append(GenericArgumentSyntax(argument: outputType))

        let genericStubType = IdentifierTypeSyntax(
            name: .identifier("Interaction"),
            genericArgumentClause: GenericArgumentClauseSyntax(
                leftAngle: .leftAngleToken(),
                arguments: GenericArgumentListSyntax(
                    genericArgs.enumerated().map { (index, arg) in
                        if index < genericArgs.count - 1 {
                            return arg.with(\.trailingComma, .commaToken())
                        }
                        return arg
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
    /// { Interaction(value, spy: doSomething)
    /// }
    /// ```
    private static func createFunctionBody(spyPropertyName: String, parameterNames: [TokenSyntax]) -> CodeBlockSyntax {
        let interactionCall = FunctionCallExprSyntax(
            callee: DeclReferenceExprSyntax(baseName: .identifier("Interaction"))
        ) {
            for name in parameterNames {
                LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: name))
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
