//
//  SwiftSyntax+Extensions.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 17/07/25.
//
import SwiftSyntax

extension DeclModifierSyntax {
    /// A boolean value indicating whether the modifier is `static`.
    var isStatic: Bool {
        name.tokenKind == .keyword(.static)
    }
}

/// How generated members reach the spies backing them.
///
/// The two strategies differ only in the expression naming a spy and in whether
/// the `adapt` family is called as an instance or static method — everything
/// else about a generated mock is identical, so the builders take this value
/// and stay otherwise shared.
public enum SpyAccess {
    /// The mock inherits `Mock`: spies are `super.name`, adapters are instance
    /// methods inherited from `Mock`.
    case inherited
    /// The mock holds a `Mock`: spies are `mock.name` (or `staticMock.name` in
    /// a static member), adapters are `Mock`'s static methods, since a
    /// composing type inherits nothing from `Mock`.
    case composed

    /// The name of the stored property holding the `Mock` in a composed mock.
    static let storedPropertyName = "mock"

    /// The name of the stored property holding the `Mock` that backs *static*
    /// requirements in a composed mock.
    ///
    /// Static members cannot reach an instance property, so they need their own
    /// storage. This mirrors what `Mock.Super` does for the inheriting strategy.
    static let staticStoredPropertyName = "staticMock"

    /// The expression a spy is looked up on, for a member of the given kind.
    ///
    /// Instance storage is spelled `self.mock` rather than a bare `mock`:
    /// settable members read the spy inside an escaping closure, where Swift
    /// requires explicit `self` (`reference to property 'mock' in closure
    /// requires explicit use of 'self' to make capture semantics explicit`).
    /// `super` never needed the qualification, so this has no inherited
    /// counterpart. Static storage is a type member and needs no qualifier.
    ///
    /// - Parameter isStatic: Whether the member reading the spy is `static`.
    func spyBase(isStatic: Bool) -> ExprSyntax {
        switch self {
        case .inherited:
            return ExprSyntax(SuperExprSyntax())
        case .composed where isStatic:
            return ExprSyntax(
                DeclReferenceExprSyntax(baseName: .identifier(Self.staticStoredPropertyName))
            )
        case .composed:
            return ExprSyntax(
                MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .keyword(.self)),
                    name: .identifier(Self.storedPropertyName)
                )
            )
        }
    }

    /// A `<base>.<name>` spy reference for a member of the given kind.
    func spyReference(_ name: TokenSyntax, isStatic: Bool) -> ExprSyntax {
        ExprSyntax(
            MemberAccessExprSyntax(
                base: spyBase(isStatic: isStatic),
                name: name
            )
        )
    }

    /// The callee for an adapter call — bare for the inherited instance method,
    /// `Mock.`-qualified for the static one a composing type must use.
    func adapterCallee(_ adapterName: String) -> ExprSyntax {
        switch self {
        case .inherited:
            return ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(adapterName)))
        case .composed:
            return ExprSyntax(
                MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .identifier("Mock")),
                    name: .identifier(adapterName)
                )
            )
        }
    }
}

extension DeclModifierListSyntax {
    /// The modifiers with `mutating` and `nonmutating` removed.
    ///
    /// Both are legal on a protocol requirement but not on the member generated
    /// from it, because mocks are classes: `'mutating' is not valid on instance
    /// methods in classes`. A class satisfies a `mutating` requirement by
    /// declaring the method without the modifier, so dropping it is what makes
    /// the conformance compile — callers are unaffected, including through
    /// generic and existential references.
    var withoutValueTypeModifiers: DeclModifierListSyntax {
        filter { modifier in
            modifier.name.tokenKind != .keyword(.mutating)
                && modifier.name.tokenKind != .keyword(.nonmutating)
        }
    }
}

extension VariableDeclSyntax {
    /// A boolean value indicating whether the variable has a getter.
    var hasGetter: Bool {
        bindings.first?.accessorBlock?.accessors.hasGetter ?? false
    }
    /// A boolean value indicating whether the variable has a setter.
    var hasSetter: Bool {
        bindings.first?.accessorBlock?.accessors.hasSetter ?? false
    }

    /// The name of the variable.
    var name: TokenSyntax {
        bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier ?? "Unknown"
    }
}

extension SubscriptDeclSyntax {
    /// A boolean value indicating whether the subscript has a setter.
    var hasSetter: Bool {
        accessorBlock?.accessors.hasSetter ?? false
    }
}

extension String {
    /// The string with its first character uppercased and the rest left intact.
    ///
    /// Distinct from `capitalized`, which lowercases everything after the first
    /// character and so mangles camelCase spy names — `cachePolicy` would yield
    /// `setCachepolicy` rather than `setCachePolicy`.
    var upperCamelCased: String {
        prefix(1).uppercased() + dropFirst()
    }

    /// The name of the write spy paired with this read-spy name.
    var setterSpyName: String {
        "set" + upperCamelCased
    }
}

extension SubscriptDeclSyntax {
    /// The spy name for the subscript: `subscript` followed by its parameter
    /// names in camelCase — `subscript(row: Int, column: Int)` names
    /// `subscriptRowColumn`, and a subscript with no named parameter is just
    /// `subscript`.
    ///
    /// The prefix keeps subscripts in their own namespace. Without it a
    /// subscript's spy name is indistinguishable from a method's or a
    /// variable's — `func index(_:)` and `subscript(index:)` both derived
    /// `index` — and requirements whose spy *signatures* also matched would
    /// silently share one spy, so stubbing one answered calls to the other.
    /// Since the name is ours to choose, namespacing removes the collision at
    /// its source rather than asking users to rename their protocol members.
    ///
    /// Unlabeled parameters contribute their internal name. The write spy is
    /// ``Swift/String/setterSpyName``, matching variables (`setValue`).
    var name: String {
        let names = parameterClause.parameters
            .compactMap { parameter -> String? in
                if let secondName = parameter.secondName {
                    return secondName.text
                }
                return parameter.firstName.text == "_" ? nil : parameter.firstName.text
            }
        guard let first = names.first else {
            return "subscript"
        }
        return "subscript" + ([first] + names.dropFirst()).map(\.upperCamelCased).joined()
    }
}

extension AccessorBlockSyntax.Accessors {
  /// The list of accessors, if the accessor block is of the `.accessors` case.
  var settersAndGetters: AccessorDeclListSyntax? {
    switch self {
    case .accessors(let settersAndGetters):
      return settersAndGetters
    case .getter(_):
      return nil
    }
  }

  /// A boolean value indicating whether the accessor block has a getter.
  var hasGetter: Bool {
    settersAndGetters?.first(where:  { $0.accessorSpecifier.text == TokenSyntax.keyword(.get).text }) != nil
  }

  /// A boolean value indicating whether the accessor block has a setter.
  var hasSetter: Bool {
    settersAndGetters?.first(where:  { $0.accessorSpecifier.text == TokenSyntax.keyword(.set).text}) != nil
  }
}
