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
