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

/// The identifier generated code uses for the value being written.
///
/// Deliberately not the implicit `newValue`: a requirement may declare a
/// parameter of that name — `subscript(newValue: Int) -> String { get set }` —
/// in which case the setter's implicit binding and the write closure's
/// parameter both shadow the index, silently dropping the index matcher and
/// failing to compile. Backticks do not help (`` `newValue` `` is the same
/// identifier), so generated code binds this reserved spelling explicitly and
/// never relies on the implicit one.
let writtenValueIdentifier = "__mockableNewValue"

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
    /// The interaction name for the subscript: its parameter names concatenated
    /// in camelCase — `subscript(row: Int, column: Int)` names `rowColumn` —
    /// mirroring how variables name their interactions (`value`).
    ///
    /// Unlabeled parameters contribute their internal name; a subscript with no
    /// named parameter at all falls back to `subscript`. The write spy is
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
        return ([first] + names.dropFirst().map(\.upperCamelCased)).joined()
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
