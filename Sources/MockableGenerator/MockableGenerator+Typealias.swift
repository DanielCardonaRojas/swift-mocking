import SwiftSyntax
import SwiftSyntaxBuilder

extension MockableGenerator {
    static func makeConformanceTypealias(protocolName: String, mockName: String) -> DeclSyntax {
        let typealiasName = "Conformance"

        let typealiasDecl = TypeAliasDeclSyntax(
            name: .identifier(typealiasName),
            initializer: TypeInitializerClauseSyntax(
                value: MemberTypeSyntax(
                    baseType: IdentifierTypeSyntax(
                        name: .identifier("Witness")
                    ),
                    name: .identifier("Synthesized")
                )
            )
        )

        return DeclSyntax(typealiasDecl)
    }
    static func makeTypealiasDecl(protocolName: String, mockName: String) -> DeclSyntax {
        let witnessTypeName = protocolName + "Witness"
        let typealiasName = "Witness"

        let typealiasDecl = TypeAliasDeclSyntax(
            name: .identifier(typealiasName),
            initializer: TypeInitializerClauseSyntax(
                value: IdentifierTypeSyntax(
                    name: .identifier(witnessTypeName),
                    genericArgumentClause: GenericArgumentClauseSyntax(
                        arguments: GenericArgumentListSyntax(
                            [
                                GenericArgumentSyntax(
                                    argument: IdentifierTypeSyntax(name: .identifier(mockName))
                                )
                            ]
                        )
                    )
                )
            )
        )

        return DeclSyntax(typealiasDecl)
    }
}
