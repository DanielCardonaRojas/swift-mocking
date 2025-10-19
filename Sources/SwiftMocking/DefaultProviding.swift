
//
//  DefaultProvidable.swift
//  MockableTypes
//
//  Created by Daniel Cardona on 11/07/25.
//

import Foundation

/// A type that can provide a default value.
///
/// Conforming to this protocol allows a type to be used in mocks where a default value is needed for unstubbed methods.
public struct DefaultProviding {
    var createDefault: () -> Any
    var defaultType: ParsedType

    public init<T>(_ type: T.Type, create: @escaping () -> T) {
        createDefault = create
        defaultType = MetatypeParser.parse(T.self)
    }

}

public extension DefaultProviding {
    static func numeric<T: Numeric>(_ type: T.Type) -> DefaultProviding {
        .init(T.self, create: { 0 })
    }

    static func array() -> DefaultProviding {
        .init(Array<Any>.self, create: { [] })
    }

    static func void() -> DefaultProviding {
        .init(Void.self, create: { return })
    }

    static func set() -> DefaultProviding {
        .init(Set<AnyHashable>.self, create: { [] })
    }

    static func dictionary() -> DefaultProviding {
        .init(Dictionary<AnyHashable, Any>.self, create: { [:] })
    }

    static func optional() -> DefaultProviding {
        .init(Optional<Any>.self, create: { nil })
    }

    static func bool() -> DefaultProviding {
        .init(Bool.self, create: { false })
    }

    static func string() -> DefaultProviding {
        .init(String.self, create: { "" })
    }

    /// Creates a provider that returns a specific concrete value.
    /// This is used by DefaultValuesTrait to register test-scoped default values.
    static func valueProvider<T>(_ value: T) -> DefaultProviding {
        .init(T.self, create: { value })
    }

}

