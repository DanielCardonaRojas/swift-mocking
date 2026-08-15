//
//  InvocationMatcher.swift
//  Mockable
//
//  Created by Daniel Cardona on 4/07/25.
//

/// A type that matches a set of arguments against a set of ``ArgMatcher``s.
///
/// This type is used to represent all parameters of a method signature.
///
/// ### Usage Example:
///
/// ```swift
/// // Create an InvocationMatcher that matches any string and an integer equal to 10
/// let matcher = InvocationMatcher(matchers: .any, .equal(10))
///
/// // Create an Invocation with actual arguments
/// let invocation = Invocation(arguments: "hello", 10)
///
/// // Check if the invocation matches the matcher
/// if matcher.isMatchedBy(invocation) {
///     print("Invocation matches!")
/// } else {
///     print("Invocation does not match.")
/// }
/// ```
public struct InvocationMatcher<each I> {
   let matchers: (repeat ArgMatcher<each I>)

    /// Initializes an `InvocationMatcher` with a variadic list of ``ArgMatcher``s.
    /// - Parameter matchers: A list of matchers, one for each argument in the method signature.
    public init(matchers: repeat ArgMatcher<each I>) {
        self.matchers = (repeat each matchers)
    }

    /// Checks if the given ``Invocation`` matches the criteria defined by this `InvocationMatcher`.
    /// - Parameter invocation: The ``Invocation`` to check against.
    /// - Returns: `true` if all arguments in the invocation match their corresponding `ArgMatcher`s, `false` otherwise.
    public func isMatchedBy(_ invocation: Invocation<repeat each I>) -> Bool {
        #if swift(>=6.0)
        for (input, matcher) in repeat (each invocation.arguments, each matchers) {
            guard matcher(input) else { return false }
        }
        return true
        #else
        // Swift 5.9 fallback: reflect both tuples (the leading scalar defeats Swift's
        // 1-tuple collapse for single-argument packs) and match positionally.
        let inputs = Mirror(reflecting: (0, invocation.arguments)).children.dropFirst().map(\.value)
        let erased = Mirror(reflecting: (0, matchers)).children.dropFirst().compactMap { ($0.value as? any AnyMatcher) }
        return zip(inputs, erased).allSatisfy { $1.matchesAny($0) }
        #endif
    }

    public var precedence: Int {
        #if swift(>=6.0)
        var sum = 0
        for matcher in repeat each matchers {
            sum += matcher.precedence.value
        }
        return sum
        #else
        return Mirror(reflecting: (0, matchers))
            .children.dropFirst()
            .compactMap { ($0.value as? any AnyMatcher) }
            .reduce(0) { $0 + $1.precedenceValue }
        #endif
    }
}

/// Type-erased view of ``ArgMatcher`` used only by the Swift 5.9 reflection fallbacks
/// above (parallel pack iteration requires Swift 6).
internal protocol AnyMatcher {
    func matchesAny(_ value: Any) -> Bool
    var precedenceValue: Int { get }
}

extension ArgMatcher: AnyMatcher {
    internal func matchesAny(_ value: Any) -> Bool {
        guard let typed = value as? Argument else { return false }
        return matcher(typed)
    }

    internal var precedenceValue: Int {
        precedence.value
    }
}

extension InvocationMatcher: Sendable where repeat each I: Sendable { }
