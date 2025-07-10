import SwiftSyntax
import SwiftSyntaxBuilder

extension MockableGenerator {
    static func makeTypealiasDecl(protocolName: String) -> DeclSyntax {
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
                                    argument: IdentifierTypeSyntax(name: .keyword(.Self))
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
