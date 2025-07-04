//
//  ArgMatcher.swift
//  Witness
//
//  Created by Daniel Cardona on 3/07/25.
//

public struct ArgMatcher<Argument> {
    let matcher: (Argument) -> Bool
    func callAsFunction(_ value: Argument) -> Bool {
        matcher(value)
    }
    static func any() -> Self {
        return .init { _ in true }
    }

}

extension ArgMatcher where Argument: Equatable {
    static func equal(_ value: Argument) -> Self {
        .init { $0 == value }
    }
}

extension ArgMatcher where Argument: Comparable {
    static func lessThan(_ value: Argument) -> Self {
        .init { $0 < value }
    }

    static func greaterThan(_ value: Argument) -> Self {
        .init { $0 > value }
    }
}

extension ArgMatcher where Argument: AnyObject {
    static func identical(_ value: Argument) -> Self {
        .init { $0 === value }
    }
}

extension ArgMatcher {
    static func notNil<T>() -> Self where Argument == Optional<T> {
        .init { $0 != nil }
    }

    static func `nil`<T>() -> Self where Argument == Optional<T> {
        .init { $0 == nil }
    }
}

