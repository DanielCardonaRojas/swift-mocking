import SwiftSyntax
import SwiftSyntaxBuilder
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
    /// struct PricingServiceMock {
    ///     typealias Witness = PricingServiceWitness<Self>
    ///
    ///     var instance: Witness.Synthesized {
    ///         .init(context: self, witness: .init(price: adapt(\.price)))
    ///     }
    ///
    ///     let price = Spy<String, Throws, Int>()
    ///     func price(_ item: ArgMatcher<String>) -> Interaction<String, Throws, Int> {
    ///         Interaction(item, spy: price)
    ///     }
    /// }
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
        let spyMembers = try makeInteractions(protocolDecl: protocolDecl)
        let typealiasDecl = makeTypealiasDecl(protocolName: protocolName, mockName: mockName)
        let instanceProperty = makeInstanceComputedProperty(protocolDecl: protocolDecl)

        // Create the Mock struct
        let mockStruct = ClassDeclSyntax(
            name: TokenSyntax.identifier(mockName),
            inheritanceClause: InheritanceClauseSyntax(
                inheritedTypes: [
                    InheritedTypeSyntax(
                        type: IdentifierTypeSyntax(name: .identifier("Mock")),
                        trailingComma: .commaToken()
                    ),
                    InheritedTypeSyntax(type: IdentifierTypeSyntax(name: .identifier("DefaultProvider")))
            ]
            ),
            memberBlock: MemberBlockSyntax {
                var members = [MemberBlockItemSyntax]()
                members.append(MemberBlockItemSyntax(decl: typealiasDecl))
                members.append(MemberBlockItemSyntax(decl: DeclSyntax("var defaultProviderRegistry: DefaultProvidableRegistry = .shared")))
                members.append(MemberBlockItemSyntax(decl: instanceProperty))
                members.append(contentsOf: spyMembers.map { MemberBlockItemSyntax(decl: $0) })
                return MemberBlockItemListSyntax(members)
            }
        )

        return [DeclSyntax(mockStruct)]
    }

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

    public static func spyPropertyName(for funcDecl: FunctionDeclSyntax, functionNames: inout [String: Int]) -> String {
        let funcName = funcDecl.name.text
        let count = functionNames[funcName, default: 0]
        functionNames[funcName] = count + 1
        let baseName = count > 0 ? "\(funcName)_\(count)" : funcName

        if funcDecl.signature.parameterClause.parameters.isEmpty {
            return baseName + "_"
        } else {
            return baseName
        }
    }
}
