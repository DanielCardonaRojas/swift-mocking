//
//  ArgMatcher.swift
//  Witness
//
//  Created by Daniel Cardona on 3/07/25.
//

/// A type that matches arguments in a test double.
///
/// You use ``ArgMatcher`` to specify which arguments a stub should apply to, or to verify that a method was called with certain arguments.
/// The library provides a set of common matchers, such as `.any()`, `.equal(_:)`, and `.notNil()`.
public struct ArgMatcher<Argument> {
    let matcher: (Argument) -> Bool
    public func callAsFunction(_ value: Argument) -> Bool {
        matcher(value)
    }

    public static var any: Self {
        return .init { _ in true }
    }

}

public extension ArgMatcher where Argument: Equatable {
    static func equal(_ value: Argument) -> Self {
        .init { $0 == value }
    }
}

public extension ArgMatcher where Argument: Comparable {
    static func lessThan(_ value: Argument) -> Self {
        .init { $0 < value }
    }

    static func greaterThan(_ value: Argument) -> Self {
        .init { $0 > value }
    }
}

public extension ArgMatcher where Argument: AnyObject {
    static func identical(_ value: Argument) -> Self {
        .init { $0 === value }
    }
}

public extension ArgMatcher {
    static func notNil<T>() -> Self where Argument == Optional<T> {
        .init { $0 != nil }
    }

    static func `nil`<T>() -> Self where Argument == Optional<T> {
        .init { $0 == nil }
    }

    static func anyError() -> Self {
        .init { $0 as? Error != nil }
    }
}

public extension ArgMatcher where Argument: Error {
    static func error<E: Error>(_ type: E.Type) -> Self {
        .init { $0 as? E != nil }
    }
}
