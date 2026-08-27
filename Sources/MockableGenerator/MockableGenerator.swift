import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftMockingOptions

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
    /// class PricingServiceMock: Mock, @unchecked Sendable, PricingService {
    ///     func price(_ item: String) throws -> Int {
    ///         return try adaptThrowing(super.price, item)
    ///     }
    ///     func price(_ item: ArgMatcher<String>) -> Interaction<String, Throws, Int> {
    ///         Interaction(item, spy: super.price)
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
            // No naming option given — follow `.default` rather than assuming a
            // suffix, so an options list that names only non-naming options
            // (`[.composition]`) keeps the same name as a bare `@Mockable`.
            mockName = MockableOptions.default.contains(.prefixMock)
                ? "Mock" + protocolName
                : protocolName + "Mock"
        }

        // Generate the spy properties and methods using SpyGenerator
        let spyAccess: SpyAccess = codeGenOptions.contains(.composition) ? .composed : .inherited
        let genericParameters = associatedTypesToGenericArguments(
            protocolDecl: protocolDecl
        )
        let typeAliases = makeTypeAliases(protocolDecl)
        let spyStorage = makeSpyStorage(protocolDecl: protocolDecl, spyAccess: spyAccess, mockName: mockName)
        let interactions = makeInteractions(protocolDecl: protocolDecl, spyAccess: spyAccess)
        let conformanceRequirements = makeConformanceRequirements(for: protocolDecl, spyAccess: spyAccess)

        let members = separatedByBlankLines(typeAliases + spyStorage + interactions + conformanceRequirements)
            .map { MemberBlockItemSyntax(decl: $0) }

        // Create the Mock struct
        let mockStruct = ClassDeclSyntax(
            name: TokenSyntax.identifier(mockName),
            genericParameterClause: genericParameters,
            inheritanceClause: InheritanceClauseSyntax(
                inheritedTypes: inheritedTypes(
                    protocolDecl: protocolDecl,
                    spyAccess: spyAccess
                )
            ),
            memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax(members))
        )

        let ifConfigDecl = ifConfig(MemberBlockItemListSyntax {
            mockStruct
        })

        return [DeclSyntax(ifConfigDecl)]
    }

    /// Builds the generated mock's inheritance clause.
    ///
    /// Inheriting mocks are `Mock, @unchecked Sendable, <Protocol>`.
    ///
    /// Composing mocks instead restate the protocol's own inherited types first
    /// — that is the whole point of the strategy, since a protocol carrying a
    /// class constraint (`protocol Service: SomeBaseClass`) requires its
    /// conformers to inherit that class, and the slot is taken by `Mock` under
    /// the default strategy. Inherited *protocols* are harmless here: conforming
    /// to the most-derived protocol already implies them.
    ///
    /// `MockProviding` is added so `verifyZeroInteractions` accepts the mock;
    /// inheriting mocks get that conformance from `Mock` itself.
    static func inheritedTypes(
        protocolDecl: ProtocolDeclSyntax,
        spyAccess: SpyAccess
    ) -> InheritedTypeListSyntax {
        // `Mock` is `@unchecked Sendable`; conformers must restate the
        // conformance to stay warning-free under Swift 6 concurrency.
        let uncheckedSendable = TypeSyntax(
            AttributedTypeSyntax(
                specifiers: [],
                attributes: [.attribute(
                    AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier("unchecked")))
                )],
                baseType: IdentifierTypeSyntax(name: TokenSyntax.identifier("Sendable"))
            )
        )

        var types: [TypeSyntax]
        switch spyAccess {
        case .inherited:
            types = [
                TypeSyntax(IdentifierTypeSyntax(name: .identifier("Mock"))),
                uncheckedSendable,
                TypeSyntax(IdentifierTypeSyntax(name: protocolDecl.name))
            ]
        case .composed:
            let inherited = protocolDecl.inheritanceClause?.inheritedTypes
                .map { TypeSyntax(stringLiteral: $0.type.trimmedDescription) } ?? []
            types = inherited + [
                TypeSyntax(IdentifierTypeSyntax(name: protocolDecl.name)),
                TypeSyntax(IdentifierTypeSyntax(name: .identifier("MockProviding"))),
                uncheckedSendable
            ]
        }

        return InheritedTypeListSyntax(
            types.enumerated().map { index, type in
                InheritedTypeSyntax(
                    type: type,
                    trailingComma: index == types.count - 1 ? nil : .commaToken()
                )
            }
        )
    }

    /// The stored properties a composing mock keeps its spies in.
    ///
    /// Empty for the inheriting strategy, which *is* its own storage.
    ///
    /// A static property is emitted only when the protocol has static
    /// requirements: static members cannot reach an instance property, so they
    /// need separate storage — the composed counterpart of `Mock.Super`.
    static func makeSpyStorage(
        protocolDecl: ProtocolDeclSyntax,
        spyAccess: SpyAccess,
        mockName: String
    ) -> [DeclSyntax] {
        guard case .composed = spyAccess else { return [] }

        var decls: [DeclSyntax] = [
            "let \(raw: SpyAccess.storedPropertyName) = Mock()"
        ]
        if hasStaticMembers(protocolDecl: protocolDecl) {
            // Keyed by the mock's own type name so these spies land in
            // `MockScope`'s scoped storage under the same identity an
            // inheriting mock's static spies use — without that they bypass
            // scoping entirely and leak across tests.
            decls.append(
                "static let \(raw: SpyAccess.staticStoredPropertyName) = Mock(scopedStorageKey: \(literal: mockName))"
            )
        }
        return decls
    }

    /// Inserts a blank line before every member but the first.
    ///
    /// Members come from three independent builders (type aliases,
    /// interactions, conformance requirements), none of which knows what
    /// precedes it, so separation is applied once here where the whole list is
    /// known.
    ///
    /// The newline goes on the member's *first token* rather than on the
    /// enclosing `MemberBlockItemSyntax`, because that is the trivia
    /// `BasicFormat` reads: it prepends a newline only when the token does not
    /// already start with one, and re-indents whatever newlines it finds. A
    /// newline parked on the member block item instead lands ahead of the
    /// declaration's own indentation and leaves the line misindented.
    static func separatedByBlankLines(_ decls: [DeclSyntax]) -> [DeclSyntax] {
        decls.enumerated().map { index, decl in
            guard index > 0 else { return decl }
            return DeclSyntax(decl.with(\.leadingTrivia, .newlines(2) + decl.leadingTrivia))
        }
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
    ///
    /// Subscripts count alongside functions and variables: a `static subscript`
    /// generates members that read `staticMock`, so omitting it from this check
    /// produced a mock referencing storage that was never declared.
    private static func hasStaticMembers(protocolDecl: ProtocolDeclSyntax) -> Bool {
        protocolDecl.memberBlock.members.contains { member in
            let modifiers: DeclModifierListSyntax?
            switch member.decl.as(DeclSyntaxEnum.self) {
            case .functionDecl(let decl): modifiers = decl.modifiers
            case .variableDecl(let decl): modifiers = decl.modifiers
            case .subscriptDecl(let decl): modifiers = decl.modifiers
            default: modifiers = nil
            }
            return modifiers?.contains(where: \.isStatic) ?? false
        }
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
                return .default
            }

            guard let arguments = attr.arguments?.as(LabeledExprListSyntax.self) else {
                // No arguments or unexpected format
                return .default
            }
            for argument in arguments {
                guard let parsedOption = MockableOptions(stringLiteral: argument.expression.description) else {
                    continue
                }
                return parsedOption
            }
        }
        return .default
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

    /// Wraps a list of member declarations in an `#if DEBUG` block.
    ///
    /// This ensures that the generated mock code is only compiled in `DEBUG` configurations.
    ///
    /// For example, given a mock class declaration, this function will generate:
    /// ```swift
    /// #if DEBUG
    /// class MyServiceMock: Mock, MyService {
    ///     // ...
    /// }
    /// #endif
    /// ```
    static func ifConfig(_ members: MemberBlockItemListSyntax) -> IfConfigDeclSyntax {
        IfConfigDeclSyntax(clauses: IfConfigClauseListSyntax(itemsBuilder: {
            IfConfigClauseSyntax(
                poundKeyword: .poundIfToken(),
                condition: ExprSyntax("DEBUG"),
                elements: IfConfigClauseSyntax.Elements
                    .decls(members)
            )
        }))
    }
}
