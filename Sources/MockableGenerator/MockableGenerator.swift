import SwiftSyntax
import SwiftSyntaxBuilder
import MockableTypes
import MockableTypes

public enum MockableGenerator {
    /// Processes a protocol declaration to generate a mock struct.
    ///
    /// This function takes a `ProtocolDeclSyntax` and generates a corresponding mock struct
    /// with spy properties and stubbing methods for each function in the protocol.
    ///
    /// For example, given the following protocol:
    /// ```swift
    /// protocol PricingService {
    ///     func price(_ item: String) throws -> Int
    /// }
    /// ```
    /// This function will generate the following structure:
    /// ```swift
    ///class PricingServiceMock: Mock, PricingService {
    ///     func price(_ item: String) throws -> Int {
    ///         return try adaptThrowing(super.price, item)
    ///     }
    ///     func price(_ item: ArgMatcher<String>) -> Interaction<String, Throws, Int> {
    ///         Interaction(item, spy: super.price)
    ///     }
    ///}
    /// ```
    public static func processProtocol(protocolDecl: ProtocolDeclSyntax) throws -> [DeclSyntax] {
        let protocolName = protocolDecl.name.text
        let codeGenOptions = MockableGenerator.codeGenOptions(protocolDecl: protocolDecl)
        let mockName: String
        if codeGenOptions.contains(.prefixMock) {
            mockName = "Mock" + protocolName
        } else if codeGenOptions.contains(.suffixMock) {
            mockName = protocolName + "Mock"
        } else {
            // Default behavior if no specific option is provided
            mockName = protocolName + "Mock"
        }

        // Generate the spy properties and methods using SpyGenerator
        let genericParameters = associatedTypesToGenericArguments(
            protocolDecl: protocolDecl
        )
        let typeAliases = makeTypeAliases(protocolDecl)
        let interactions = makeInteractions(protocolDecl: protocolDecl)
        let conformanceRequirements = makeConformanceRequirements(for: protocolDecl)

        // Create the Mock struct
        let mockStruct = ClassDeclSyntax(
            name: TokenSyntax.identifier(mockName),
            genericParameterClause: genericParameters,
            inheritanceClause: InheritanceClauseSyntax(
                inheritedTypes: [
                    InheritedTypeSyntax(
                        type: IdentifierTypeSyntax(
                            name: .identifier("Mock")
                        ),
                        trailingComma: .commaToken()
                    ),
                    InheritedTypeSyntax(
                        type: IdentifierTypeSyntax(name: protocolDecl.name)
                    )
                ]
            ),
            memberBlock: MemberBlockSyntax {
                var members = [MemberBlockItemSyntax]()
                members.append(contentsOf: typeAliases.map({ MemberBlockItemSyntax(decl: $0)}))
                members.append(contentsOf: conformanceRequirements.map { MemberBlockItemSyntax(decl: $0) })
                members.append(contentsOf: interactions.map { MemberBlockItemSyntax(decl: $0) })
                return MemberBlockItemListSyntax(members)
            }
        )

        return [DeclSyntax(mockStruct)]
    }

    /// Checks if a protocol has any static members.
    ///
    /// This function iterates through the members of a protocol and returns `true` if any of them are declared as `static`.
    ///
    /// For example, for the following protocol:
    /// ```swift
    /// protocol MyService {
    ///     static func doSomething()
    /// }
    /// ```
    /// This function will return `true`.
    private static func hasStaticMembers(protocolDecl: ProtocolDeclSyntax) -> Bool {
        for member in protocolDecl.memberBlock.members {
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                if funcDecl.modifiers.contains(where: { $0.name.text == "static" }) {
                    return true
                }
            } else if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                if varDecl.modifiers.contains(where: { $0.name.text == "static" }) {
                    return true
                }
            }
        }
        return false
    }

    /// Extracts mock generation options from a protocol's attributes.
    ///
    /// This function looks for a `@Mockable` attribute on a protocol and parses its arguments to determine code generation options.
    ///
    /// For example, for the following protocol:
    /// ```swift
    /// @Mockable(.prefixMock)
    /// protocol MyService {
    ///     // ...
    /// }
    /// ```
    /// This function will return `[.prefixMock]`.
    public static func codeGenOptions(protocolDecl: ProtocolDeclSyntax) -> MockableOptions {
        for attribute in protocolDecl.attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else {
                return []
            }

            guard let arguments = attr.arguments?.as(LabeledExprListSyntax.self) else {
                // No arguments or unexpected format
                return []
            }
            for argument in arguments {
                guard let parsedOption = MockableOptions(stringLiteral: argument.expression.description) else {
                    continue
                }
                return parsedOption
            }
        }
        return []
    }

    /// Extracts all associated type declarations from a protocol.
    ///
    /// For example, for the following protocol:
    /// ```swift
    /// protocol MyService {
    ///     associatedtype Item
    /// }
    /// ```
    /// This function will return an array containing the `AssociatedTypeDeclSyntax` for `Item`.
    static func associatedTypes(protocolDecl: ProtocolDeclSyntax) -> [AssociatedTypeDeclSyntax] {
        protocolDecl.memberBlock.members.compactMap({ $0.decl.as(AssociatedTypeDeclSyntax.self)})
    }

    /// Converts associated types of a protocol into a generic parameter clause.
    ///
    /// This is used to make the generated mock class generic over the associated types of the protocol.
    ///
    /// For example, for the following protocol:
    /// ```swift
    /// protocol MyService {
    ///     associatedtype Item: Equatable
    /// }
    /// ```
    /// This function will generate the following clause:
    /// ```swift
    /// <Item: Equatable>
    /// ```
    static func associatedTypesToGenericArguments(protocolDecl: ProtocolDeclSyntax) -> GenericParameterClauseSyntax? {
        let paramList = GenericParameterListSyntax {
            for associatedType in associatedTypes(protocolDecl: protocolDecl) {
                GenericParameterSyntax(
                    name: associatedType.name,
                    colon: associatedType.inheritanceClause != nil ? .colonToken() : nil,
                    inheritedType: associatedType.inheritanceClause?.inheritedTypes.first?.type
                )
            }
        }

        if paramList.isEmpty {
            return nil
        }

        return GenericParameterClauseSyntax(parameters: paramList)
    }

    /// Creates type aliases for the associated types of a protocol.
    ///
    /// This is used within the generated mock to map the generic parameters of the mock to the associated types of the protocol.
    ///
    /// For example, for the following protocol:
    /// ```swift
    /// protocol MyService {
    ///     associatedtype Item
    /// }
    /// ```
    /// This function will generate the following type alias:
    /// ```swift
    /// typealias Item = Item
    /// ```
    static func makeTypeAliases(_ protocolDecl: ProtocolDeclSyntax) -> [DeclSyntax] {
        typeAliasesForAssociatedTypes(protocolDecl: protocolDecl).map({
            DeclSyntax($0)
        })
    }

    /// Creates type alias declarations for each associated type in a protocol.
    ///
    /// For example, for the following protocol:
    /// ```swift
    /// protocol MyService {
    ///     associatedtype Item
    /// }
    /// ```
    /// This function will generate the following type alias declaration:
    /// ```swift
    /// typealias Item = Item
    /// ```
    static func typeAliasesForAssociatedTypes(protocolDecl: ProtocolDeclSyntax) -> [TypeAliasDeclSyntax] {
        var result = [TypeAliasDeclSyntax]()
        for associatedType in associatedTypes(protocolDecl: protocolDecl) {
            let alias = TypeAliasDeclSyntax(
                name: associatedType.name,
                initializer: TypeInitializerClauseSyntax(
                    value: TypeSyntax(stringLiteral: associatedType.name.text)
                )
            )
            result.append(alias)
        }

        return result
    }
}
