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
