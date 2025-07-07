import SwiftSyntax
import SwiftSyntaxBuilder

extension MockableGenerator {
    static func makeTypealiasDecl(protocolName: String, spyingName: String) -> DeclSyntax {
        let witnessTypeName = protocolName + "Witness"
        let typealiasName = protocolName + "MockWitness"

        let typealiasDecl = TypeAliasDeclSyntax(
            name: .identifier(typealiasName),
            initializer: TypeInitializerClauseSyntax(
                value: IdentifierTypeSyntax(
                    name: .identifier(witnessTypeName),
                    genericArgumentClause: GenericArgumentClauseSyntax(
                        arguments: GenericArgumentListSyntax(
                            [
                                GenericArgumentSyntax(
                                    argument: IdentifierTypeSyntax(name: .identifier(spyingName))
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
