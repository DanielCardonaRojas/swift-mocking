
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
public struct AnyDefaultProviding {
    var createDefault: () -> Any
    var defaultType: ParsedType

    init<T>(_ type: T.Type, create: @escaping () -> T) {
        createDefault = create
        defaultType = MetatypeParser.parse(T.self)
    }

}

public extension AnyDefaultProviding {
    static func numeric<T: Numeric>(_ type: T.Type) -> AnyDefaultProviding {
        .init(T.self, create: {
            0
        })
    }

    static func array() -> AnyDefaultProviding {
        .init(Array<Any>.self, create: {
            []
        })
    }

    static func void() -> AnyDefaultProviding {
        .init(Void.self, create: {
            return

        })
    }

    static func set() -> AnyDefaultProviding {
        .init(Set<AnyHashable>.self, create: {
            []
        })
    }

    static func dictionary() -> AnyDefaultProviding {
        .init(Dictionary<AnyHashable, Any>.self, create: {
            [:]
        })
    }

    static func optional() -> AnyDefaultProviding {
        .init(Optional<Any>.self, create: {
            nil
        })
    }

    static func bool() -> AnyDefaultProviding {
        .init(Bool.self, create: { false })
    }

    static func string() -> AnyDefaultProviding {
        .init(String.self, create: { "" })
    }

}

