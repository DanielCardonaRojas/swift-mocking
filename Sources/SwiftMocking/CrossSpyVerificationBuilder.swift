//
//  CrossSpyVerificationBuilder.swift
//  SwiftMocking
//
//  Created by Daniel Cardona
//

/// A result builder for collecting cross-spy verifications in a declarative way.
///
/// This builder enables ergonomic verification of call sequences across multiple
/// mock objects using a closure syntax. It's used with the `verifyInOrder` function.
///
/// Example:
/// ```swift
/// verifyInOrder {
///     mock1.firstMethod()
///     mock2.secondMethod(arg: 1)
///     mock1.thirdMethod()
/// }
/// ```
@resultBuilder
public struct CrossSpyVerificationBuilder {
    public static func buildBlock(_ components: [any CrossSpyVerifiable]...) -> [any CrossSpyVerifiable] {
        var result = [[any CrossSpyVerifiable]]()
        for component in components {
            result.append(component)
        }
        return result.flatMap({ $0 })
    }

    public static func buildExpression(_ expression: any CrossSpyVerifiable) -> [any CrossSpyVerifiable] {
        [expression]
    }

    public static func buildEither(first component: [any CrossSpyVerifiable]) -> [any CrossSpyVerifiable] {
        component
    }

    public static func buildEither(second component: [any CrossSpyVerifiable]) -> [any CrossSpyVerifiable] {
        component
    }

    public static func buildOptional(_ component: [any CrossSpyVerifiable]?) -> [any CrossSpyVerifiable] {
        component ?? []
    }
}
