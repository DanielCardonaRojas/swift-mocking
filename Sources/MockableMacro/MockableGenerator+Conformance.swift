
import SwiftSyntax
import SwiftSyntaxBuilder

extension MockableGenerator {
    static func makeNewFunction(protocolDecl: ProtocolDeclSyntax) -> DeclSyntax {
        let protocolName = protocolDecl.name.text
        let mockWitnessTypeName = "\(protocolName)MockWitness"

        let returnType = MemberTypeSyntax(
            baseType: IdentifierTypeSyntax(name: .identifier(mockWitnessTypeName)),
            name: .identifier("Synthesized")
        )
        
        let funcDecls = protocolDecl.memberBlock.members.compactMap { $0.decl.as(FunctionDeclSyntax.self) }

        let witnessArguments = LabeledExprListSyntax {
            for funcDecl in funcDecls {
                let funcName = funcDecl.name.text

                let adaptCall = FunctionCallExprSyntax(
                    callee: DeclReferenceExprSyntax(baseName: .identifier("adapt"))
                ) {
                    LabeledExprSyntax(
                        expression: KeyPathExprSyntax(
                            backslash: .backslashToken(),
                            components: [
                                KeyPathComponentSyntax(
                                    period: .periodToken(),
                                    component: .property(
                                        .init(declName: DeclReferenceExprSyntax(baseName: .identifier(funcName)))
                                    )
                                )
                            ]
                        )
                    )
                }

                LabeledExprSyntax(
                    label: .identifier(funcName),
                    colon: .colonToken(trailingTrivia: .space),
                    expression: adaptCall
                )
            }
        }

        let witnessInit = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(name: .keyword(.`init`)),
            leftParen: .leftParenToken(),
            arguments: witnessArguments,
            rightParen: .rightParenToken()
        )

        let contextInit = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(name: .keyword(.`init`)),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax(),
            rightParen: .rightParenToken()
        )

        let outerInitArguments = LabeledExprListSyntax {
            LabeledExprSyntax(label: "context", colon: .colonToken(trailingTrivia: .space), expression: contextInit)
            LabeledExprSyntax(label: "witness", colon: .colonToken(trailingTrivia: .space), expression: witnessInit)
        }
        
        let outerInit = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(name: .keyword(.`init`)),
            leftParen: .leftParenToken(),
            arguments: outerInitArguments,
            rightParen: .rightParenToken()
        )

        let newFunc = FunctionDeclSyntax(
            modifiers: [DeclModifierSyntax(name: .keyword(.static), trailingTrivia: .space)],
            name: .identifier("new"),
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(parameters: []),
                returnClause: ReturnClauseSyntax(arrow: .arrowToken(leadingTrivia: .space, trailingTrivia: .space), type: returnType)
            ),
            body: CodeBlockSyntax(
                leftBrace: .leftBraceToken(leadingTrivia: .space),
                statements: [
                    CodeBlockItemSyntax(item: .expr(ExprSyntax(outerInit)))
                ],
                rightBrace: .rightBraceToken()
            )
        )

        return DeclSyntax(newFunc)
    }
}

