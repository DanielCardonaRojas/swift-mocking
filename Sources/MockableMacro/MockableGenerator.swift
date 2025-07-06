import SwiftSyntax
import SwiftSyntaxBuilder

struct MacroError: Error {
    let message: String
}

public enum MockableGenerator {
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
    /// public struct MyServiceSpy {
    ///     public let doSomething = Spy<String, None, Int>()
    ///     public func doSomething(with value: ArgMatcher<String>) -> Stub<String, None, Int> {
    ///         doSomething.when(calledWith: value)
    ///     }
    /// }
    /// ```
    public static func processProtocol(protocolDecl: ProtocolDeclSyntax) throws -> [DeclSyntax] {
        let spyName = protocolDecl.name.text + "Spy"
        var members = [DeclSyntax]()
        var functionNames = [String: Int]()

        for member in protocolDecl.memberBlock.members {
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                let (spyProperty, stubFunction) = try processFunc(funcDecl, &functionNames)
                members.append(spyProperty)
                members.append(stubFunction)
            }
        }

        let spyStruct = StructDeclSyntax(
            modifiers: [DeclModifierSyntax(name: .keyword(.public))],
            name: TokenSyntax.identifier(spyName),
            memberBlock: MemberBlockSyntax {
                MemberBlockItemListSyntax(members.map { MemberBlockItemSyntax(decl: $0) })
            }
        )

        return [DeclSyntax(spyStruct)]
    }

    /// Processes a function declaration to generate a spy property and a stubbing function.
    private static func processFunc(_ funcDecl: FunctionDeclSyntax, _ functionNames: inout [String: Int]) throws -> (DeclSyntax, DeclSyntax) {
        let funcName = funcDecl.name.text
        let count = functionNames[funcName, default: 0]
        functionNames[funcName] = count + 1
        let spyPropertyName = count > 0 ? "\(funcName)_\(count)" : funcName

        let (inputTypes, parameterNames) = getFunctionParameters(funcDecl)
        let outputType = getFunctionReturnType(funcDecl)
        let effectType = getFunctionEffectType(funcDecl)

        let spyProperty = try createSpyProperty(
            name: spyPropertyName,
            inputTypes: inputTypes,
            outputType: outputType,
            effectType: effectType
        )

        let stubFunction = try createStubFunction(
            name: funcName,
            spyPropertyName: spyPropertyName,
            inputTypes: inputTypes,
            outputType: outputType,
            effectType: effectType,
            parameterNames: parameterNames
        )

        return (DeclSyntax(spyProperty), DeclSyntax(stubFunction))
    }

    /// Extracts the parameter types and names from a function declaration.
    private static func getFunctionParameters(_ funcDecl: FunctionDeclSyntax) -> ([TypeSyntax], [TokenSyntax]) {
        let parameters = funcDecl.signature.parameterClause.parameters
        let inputTypes = parameters.map { $0.type }
        let parameterNames = parameters.map { $0.firstName }
        return (inputTypes, parameterNames)
    }

    /// Extracts the return type from a function declaration.
    private static func getFunctionReturnType(_ funcDecl: FunctionDeclSyntax) -> TypeSyntax {
        return funcDecl.signature.returnClause?.type ?? TypeSyntax(stringLiteral: "Void")
    }

    /// Extracts the effect type from a function declaration.
    private static func getFunctionEffectType(_ funcDecl: FunctionDeclSyntax) -> String {
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
    /// public let doSomething = Spy<String, None, Int>()
    /// ```
    private static func createSpyProperty(name: String, inputTypes: [TypeSyntax], outputType: TypeSyntax, effectType: String) throws -> VariableDeclSyntax {
        var genericArgs = GenericArgumentListSyntax()
        for inputType in inputTypes {
            genericArgs.append(GenericArgumentSyntax(argument: inputType))
        }
        genericArgs.append(GenericArgumentSyntax(argument: TypeSyntax(stringLiteral: effectType)))
        genericArgs.append(GenericArgumentSyntax(argument: outputType))

        let genericSpy = GenericSpecializationExprSyntax(
            expression: DeclReferenceExprSyntax(baseName: .identifier("Spy")),
            genericArgumentClause: GenericArgumentClauseSyntax(arguments: genericArgs)
        )

        let initializer = InitializerClauseSyntax(value: FunctionCallExprSyntax(callee: genericSpy) { LabeledExprListSyntax() })
        let binding = PatternBindingSyntax(pattern: IdentifierPatternSyntax(identifier: .identifier(name)), initializer: initializer)
        return VariableDeclSyntax(modifiers: [DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space))], bindingSpecifier: .keyword(.let, trailingTrivia: .space), bindings: [binding])
    }

    /// Creates a stubbing function declaration.
    ///
    /// For example, for a function `doSomething(with value: String) -> Int`, this will generate:
    /// ```swift
    /// public func doSomething(with value: ArgMatcher<String>) -> Stub<String, None, Int> {
    ///    doSomething.when(calledWith: value)
    /// }
    /// ```
    private static func createStubFunction(name: String, spyPropertyName: String, inputTypes: [TypeSyntax], outputType: TypeSyntax, effectType: String, parameterNames: [TokenSyntax]) throws -> FunctionDeclSyntax {
        let parameterList = createParameterList(inputTypes: inputTypes, parameterNames: parameterNames)
        let returnType = createStubReturnType(inputTypes: inputTypes, outputType: outputType, effectType: effectType)
        let body = createFunctionBody(spyPropertyName: spyPropertyName, parameterNames: parameterNames)

        return FunctionDeclSyntax(
            modifiers: [DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space))],
            name: TokenSyntax.identifier(name),
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax { parameterList },
                returnClause: returnType
            ),
            body: body
        )
    }

    /// Creates a parameter list for a stubbing function.
    ///
    /// For example, for a function `doSomething(with value: String)`, this will generate:
    /// ```swift
    /// with value: ArgMatcher<String>
    /// ```
    private static func createParameterList(inputTypes: [TypeSyntax], parameterNames: [TokenSyntax]) -> FunctionParameterListSyntax {
        var parameters = [FunctionParameterSyntax]()
        for (index, type) in inputTypes.enumerated() {
            let parameterName = parameterNames[index]
            let param = FunctionParameterSyntax(
                firstName: parameterName,
                colon: .colonToken(trailingTrivia: .space),
                type: TypeSyntax(
                    IdentifierTypeSyntax(
                        name: .identifier("ArgMatcher"),
                        genericArgumentClause: GenericArgumentClauseSyntax { GenericArgumentSyntax(argument: type) }
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
    /// -> Stub<String, None, Int>
    /// ```
    private static func createStubReturnType(inputTypes: [TypeSyntax], outputType: TypeSyntax, effectType: String) -> ReturnClauseSyntax {
        var genericArgs = GenericArgumentListSyntax()
        for inputType in inputTypes {
            genericArgs.append(GenericArgumentSyntax(argument: inputType))
        }
        genericArgs.append(GenericArgumentSyntax(argument: TypeSyntax(stringLiteral: effectType)))
        genericArgs.append(GenericArgumentSyntax(argument: outputType))

        let genericStubType = IdentifierTypeSyntax(
            name: .identifier("Stub"),
            genericArgumentClause: GenericArgumentClauseSyntax(arguments: genericArgs)
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
    ///     doSomething.when(calledWith: value)
    /// }
    /// ```
    private static func createFunctionBody(spyPropertyName: String, parameterNames: [TokenSyntax]) -> CodeBlockSyntax {
        let whenCall = FunctionCallExprSyntax(callee: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: .identifier(spyPropertyName)),
            dot: .periodToken(),
            name: .identifier("when")
        )) { 
            for (index, name) in parameterNames.enumerated() {
                LabeledExprSyntax(label: index == 0 ? "calledWith" : nil, expression: DeclReferenceExprSyntax(baseName: name))
            }
        }

        return CodeBlockSyntax(statements: [CodeBlockItemSyntax(item: .expr(ExprSyntax(whenCall)))])
    }
}