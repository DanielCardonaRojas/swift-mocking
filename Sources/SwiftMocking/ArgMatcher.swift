//
//  ArgMatcher.swift
//  Witness
//
//  Created by Daniel Cardona on 3/07/25.
//

import Foundation

/// A type that matches arguments in a test double.
///
/// You use ``ArgMatcher`` to specify which arguments a stub should apply to, or to verify that a method was called with certain arguments.
/// The library provides a set of common matchers, such as ``ArgMatcher/any``, ``ArgMatcher/equal(_:)``, and ``ArgMatcher/notNil()``.
///
/// ### Usage Example:
///
/// ```swift
/// // Stubbing a method to return a value when called with any string
/// spy.when(calledWith: .any).thenReturn(10)
///
/// // Stubbing a method to return a value when called with a specific string
/// spy.when(calledWith: .equal("hello")).thenReturn(20)
///
/// // Verifying a method was called with a specific integer argument
/// verify(spy.someMethod(.equal(5))).called()
///
/// // Verifying a method was called with any string argument
/// verify(spy.anotherMethod(.any)).called()
/// ```
public struct ArgMatcher<Argument> {
    var precedence: MatcherPrecedence
    let matcher: (Argument) -> Bool

    public init(
        precedence: MatcherPrecedence = .typeMatch,
        matcher: @escaping (Argument) -> Bool
    ) {
        self.precedence = precedence
        self.matcher = matcher
    }

    /// Calls the underlying matcher function with the given value.
    /// - Parameter value: The argument value to match against.
    /// - Returns: `true` if the value matches, `false` otherwise.
    public func callAsFunction(_ value: Argument) -> Bool {
        matcher(value)
    }

    /// A matcher that matches any argument of the specified type.
    ///
    /// Use this when you don't care about the specific value of an argument.
    ///
    /// ```swift
    /// // Stubbing a method to return a value regardless of the input string
    /// spy.when(calledWith: .any).thenReturn(10)
    ///
    /// // Verifying a method was called with any integer argument
    /// verify(spy.someMethod(.any)).called()
    /// ```
    public static var any: Self {
        return .init(precedence: .any) { _ in true }
    }

    /// A matcher that matches any argument of the specified type.
    ///
    /// Use this when you don't care about the specific value of an argument, but want to ensure it's of a certain type.
    ///
    /// ```swift
    /// // Verifying a method was called with any String argument
    /// verify(spy.someMethod(.any(String.self))).called()
    /// ```
    public static func any<T>(_ type: T.Type) -> ArgMatcher<T> {
        return .init(precedence: .typeMatch) { _ in true }
    }

    /// A matcher that matches any argument that satisfies a given predicate.
    ///
    /// Use this for more complex matching logic that can't be expressed with other matchers.
    ///
    /// ```swift
    /// // Stubbing a method to return a value if the integer argument is even
    /// spy.when(calledWith: .any(that: { $0 % 2 == 0 })).thenReturn("even")
    /// ```
    public static func any(that predicate: @escaping (Argument) -> Bool) -> Self {
        return .init(precedence: .predicate, matcher: predicate)
    }

    /// A matcher on Metatypes
    ///
    /// Use this to match a specific metatype.
    ///
    /// ```swift
    /// // Verifying a method was called with the String metatype
    /// verify(spy.someMethod(.type(String.self))).called()
    /// ```
    public static func type<T>(_ type: T.Type) -> ArgMatcher<T.Type> {
        .init(precedence: .equalTo, matcher: { $0 == type })
    }

    /// A matcher that matches an argument if it can be cast to a specific type.
    ///
    /// This is useful when dealing with protocols or superclasses, and you want to match a specific concrete type.
    /// For example casting an argument of type: `any CustomStringConvertible` to  `String`.
    ///
    /// - Parameter type: The type to check for casting.
    /// - Returns: An `ArgMatcher` that matches if the argument can be cast to the given type.
    public static func `as`<T>(_ type: T.Type) -> Self {
        .init(precedence: .typeMatch) { argument in
            (argument as? T) != nil
        }
    }

    /// A matcher that matches an argument if it can be cast to a specific type.
    ///
    /// This is useful when dealing with protocols or superclasses, and you want to match a specific concrete type.
    /// For example casting an argument of type: `any CustomStringConvertible` to  `String`.
    ///
    /// - Parameter type: The type to check for casting.
    /// - Returns: An `ArgMatcher` that matches if the argument can be cast to the given type.
    public static func `is`<T>(_ type: T.Type) -> Self {
        .init(precedence: .typeMatch) { argument in
            (argument as? T) != nil
        }
    }

    public static func variadic<Element>(_ matchers: ArgMatcher<Element>...) -> ArgMatcher<[Element]> {
        variadic(Array(matchers))
    }

    public static func variadic<Element>(_ matchers: [ArgMatcher<Element>]) -> ArgMatcher<[Element]> {
        .init(precedence: .typeMatch, matcher: { (arguments: [Element]) in
            guard arguments.count == matchers.count else {
                return false
            }
            for i in 0..<arguments.count {
                if !matchers[i](arguments[i]) {
                    return false
                }
            }
            return true
        })
    }
}

public extension ArgMatcher where Argument: Equatable {
    /// A matcher that matches an argument equal to the given value.
    /// - Parameter value: The value to compare against.
    ///
    /// ```swift
    /// // Stubbing a method to return 10 only when called with "specific"
    /// spy.when(calledWith: .equal("specific")).thenReturn(10)
    ///
    /// // Verifying a method was called exactly with 42
    /// verify(spy.anotherMethod(.equal(42))).called()
    /// ```
    static func equal(_ value: Argument) -> Self {
        .init(precedence: .equalTo) { $0 == value }
    }
}

// MARK: - Comparable

public extension ArgMatcher where Argument: Comparable {
    /// A matcher that matches an argument less than the given value.
    /// - Parameter value: The value to compare against.
    ///
    /// ```swift
    /// // Stubbing a method to return a value if the integer argument is less than 10
    /// spy.when(calledWith: .lessThan(10)).thenReturn("small")
    /// ```
    static func lessThan(_ value: Argument) -> Self {
        .init(precedence: .predicate) { $0 < value }
    }

    /// A matcher that matches an argument greater than the given value.
    /// - Parameter value: The value to compare against.
    ///
    /// ```swift
    /// // Verifying a method was called with an integer argument greater than 100
    /// verify(spy.processValue(.greaterThan(100))).called()
    /// ```
    static func greaterThan(_ value: Argument) -> Self {
        .init(precedence: .predicate) { $0 > value }
    }

    /// A matcher that matches an argument within a given range (inclusive).
    /// - Parameters:
    ///   - lowerBound: The minimum value (inclusive).
    ///   - upperBound: The maximum value (inclusive).
    ///
    /// ```swift
    /// // Stubbing a method to return "medium" for values between 10 and 20
    /// spy.when(calledWith: .between(10, 20)).thenReturn("medium")
    ///
    /// // Verifying a method was called with a percentage between 0 and 100
    /// verify(spy.setProgress(.between(0, 100))).called()
    /// ```
    static func between(_ lowerBound: Argument, _ upperBound: Argument) -> Self {
        .init(precedence: .predicate) { value in
            value >= lowerBound && value <= upperBound
        }
    }

    /// A matcher that matches an argument within a closed range.
    /// - Parameter range: A `ClosedRange` defining the acceptable values.
    ///
    /// ```swift
    /// // Stubbing a method for values in a range
    /// spy.when(calledWith: .in(10...20)).thenReturn("in_range")
    ///
    /// // Verifying a method was called with a value in range
    /// verify(spy.setVolume(.in(0...100))).called()
    /// ```
    static func `in`(_ range: ClosedRange<Argument>) -> Self {
        .init(precedence: .predicate) { range.contains($0) }
    }

    /// A matcher that matches an argument greater than or equal to a value.
    /// - Parameter range: A `PartialRangeFrom` defining the minimum value.
    ///
    /// ```swift
    /// // Stubbing a method for values 18 and above
    /// spy.when(calledWith: .in(18...)).thenReturn("adult")
    ///
    /// // Verifying a method was called with a minimum value
    /// verify(spy.validateAge(.in(21...))).called()
    /// ```
    static func `in`(_ range: PartialRangeFrom<Argument>) -> Self {
        .init(precedence: .predicate) { range.contains($0) }
    }

    /// A matcher that matches an argument less than or equal to a value.
    /// - Parameter range: A `PartialRangeThrough` defining the maximum value.
    ///
    /// ```swift
    /// // Stubbing a method for values up to 100
    /// spy.when(calledWith: .in(...100)).thenReturn("within_limit")
    ///
    /// // Verifying a method was called with a maximum value
    /// verify(spy.setSpeed(.in(...65))).called()
    /// ```
    static func `in`(_ range: PartialRangeThrough<Argument>) -> Self {
        .init(precedence: .predicate) { range.contains($0) }
    }
}

public extension ArgMatcher where Argument: FloatingPoint {
    /// A matcher that matches a floating-point argument approximately equal to the given value.
    /// - Parameters:
    ///   - value: The target value to compare against.
    ///   - tolerance: The acceptable difference (defaults to 0.001).
    ///
    /// ```swift
    /// // Stubbing a method for values approximately equal to π
    /// spy.when(calledWith: .approximately(3.14159, tolerance: 0.001)).thenReturn("pi")
    ///
    /// // Verifying a method was called with a value close to 2.5
    /// verify(spy.calculate(.approximately(2.5))).called()
    /// ```
    static func approximately(_ value: Argument, tolerance: Argument = 0.001) -> Self {
        .init(precedence: .predicate) { argument in
            abs(argument - value) <= tolerance
        }
    }
}

public extension ArgMatcher where Argument: AnyObject {
    /// A matcher that matches an argument that is identical (same instance) to the given object.
    /// - Parameter value: The object instance to compare against.
    ///
    /// ```swift
    /// class MyObject {}
    /// let obj = MyObject()
    /// // Stubbing a method to return a value only when called with the exact instance 'obj'
    /// spy.when(calledWith: .identical(obj)).thenReturn("same instance")
    /// ```
    static func identical(_ value: Argument) -> Self {
        .init(precedence: .identicalTo) { $0 === value }
    }
}

public extension ArgMatcher {
    /// A matcher that matches a non-nil optional argument.
    ///
    /// ```swift
    /// // Verifying a method was called with a non-nil optional string
    /// verify(spy.handleOptional(.notNil())).called()
    /// ```
    static func notNil<T>() -> Self where Argument == Optional<T> {
        .init(precedence: .predicate) { $0 != nil }
    }

    /// A matcher that matches a nil optional argument.
    ///
    /// ```swift
    /// // Stubbing a method to return a default value when called with a nil optional integer
    /// spy.when(calledWith: .nil()).thenReturn(0)
    /// ```
    static func `nil`<T>() -> Self where Argument == Optional<T> {
        .init(precedence: .predicate) { $0 == nil }
    }

    /// A matcher that matches any `Error` type.
    ///
    /// ```swift
    /// // Verifying a method threw any error
    /// verify(spy.performAction()).throws(.anyError())
    /// ```
    static func anyError() -> Self {
        .init(precedence: .typeMatch) { $0 as? Error != nil }
    }
}

public extension ArgMatcher where Argument: Error {
    /// A matcher that matches an error of a specific type.
    /// - Parameter type: The type of the error to match.
    ///
    /// ```swift
    /// enum MyError: Error { case invalid }
    /// // Verifying a method threw an error of type MyError
    /// verify(spy.processData()).throws(.error(MyError.self))
    /// ```
    static func error<E: Error>(_ type: E.Type) -> Self {
        .init(precedence: .typeMatch) { $0 as? E != nil }
    }
}

// MARK: - Custom types
public extension ArgMatcher {
    /// A matcher that matches any argument where a specific property of the argument is equal to a given value.
    ///
    /// This is useful for matching arguments based on a nested property, especially when the argument itself
    /// might not be `Equatable` or when you only care about a specific part of it.
    ///
    /// Example:
    /// ```swift
    /// struct User {
    ///     let id: String
    ///     let name: String
    /// }
    ///
    /// protocol UserService {
    ///     func getUser(user: User) -> User?
    /// }
    ///
    /// // Stub the getUser method to return a user when the id property of the argument is "123"
    /// when(mockUserService.getUser(user: .any(where: \.id, "123"))).thenReturn(User(id: "123", name: "Test User"))
    ///
    /// // Verify that getUser was called with a user whose name property is "Alice"
    /// verify(mockUserService.getUser(user: .any(where: \.name, "Alice"))).called()
    /// ```
    ///
    /// - Parameters:
    ///   - keyPath: A `KeyPath` to the property of the `Argument` type that should be compared.
    ///   - value: The `Equatable` value to compare the property against.
    /// - Returns: An `ArgMatcher` that matches arguments where the specified property equals the given value.
    static func any<Property: Equatable>(where keyPath: KeyPath<Argument, Property>, _ value: Property) -> Self {
        .init(precedence: .predicate) { $0[keyPath: keyPath] == value }
    }
}

// MARK: - Expressible by literal

extension ArgMatcher: ExpressibleByIntegerLiteral where Argument == IntegerLiteralType {
    /// Initializes an `ArgMatcher` with an integer literal, matching arguments equal to the literal value.
    public init(integerLiteral value: IntegerLiteralType) {
      self = .equal(value)
  }
}

extension ArgMatcher: ExpressibleByFloatLiteral where Argument == FloatLiteralType {
    /// Initializes an `ArgMatcher` with a float literal, matching arguments equal to the literal value.
  public init(floatLiteral value: FloatLiteralType) {
      self = .equal(value)
  }
}

extension ArgMatcher: ExpressibleByBooleanLiteral where Argument == BooleanLiteralType {
    /// Initializes an `ArgMatcher` with a boolean literal, matching arguments equal to the literal value.
  public init(booleanLiteral value: BooleanLiteralType) {
      self = .equal(value)
  }
}

extension ArgMatcher: ExpressibleByUnicodeScalarLiteral where Argument == String {
    /// Initializes an `ArgMatcher` with a Unicode scalar literal, matching arguments equal to the literal string.
  public init(unicodeScalarLiteral value: Argument) {
      self = .equal(value)
  }
}

extension ArgMatcher: ExpressibleByExtendedGraphemeClusterLiteral where Argument == String {
    /// Initializes an `ArgMatcher` with an extended grapheme cluster literal, matching arguments equal to the literal string.
  public init(extendedGraphemeClusterLiteral value: Argument) {
      self = .equal(value)
  }
}

extension ArgMatcher: ExpressibleByStringLiteral where Argument == String {
    /// Initializes an `ArgMatcher` with a string literal, matching arguments equal to the literal string.
  public init(stringLiteral value: Argument) {
      self = .equal(value)
  }
}

// MARK: - String
public extension ArgMatcher where Argument == String {
    /// A matcher that matches a string argument that contains the given substring.
    /// - Parameter substring: The substring to search for.
    ///
    /// ```swift
    /// // Stubbing a method for any string containing "error"
    /// spy.when(calledWith: .contains("error")).thenReturn("handle_error")
    ///
    /// // Verifying a method was called with a string containing "success"
    /// verify(spy.logMessage(.contains("success"))).called()
    /// ```
    static func contains(_ substring: String) -> Self {
        .init(precedence: .predicate) { $0.contains(substring) }
    }

    /// A matcher that matches a string argument that starts with the given prefix.
    /// - Parameter prefix: The prefix to match.
    ///
    /// ```swift
    /// // Stubbing a method for any string starting with "http"
    /// spy.when(calledWith: .startsWith("http")).thenReturn("web_url")
    ///
    /// // Verifying a method was called with a string starting with "DEBUG:"
    /// verify(spy.log(.startsWith("DEBUG:"))).called()
    /// ```
    static func startsWith(_ prefix: String) -> Self {
        .init(precedence: .predicate) { $0.hasPrefix(prefix) }
    }

    /// A matcher that matches a string argument that ends with the given suffix.
    /// - Parameter suffix: The suffix to match.
    ///
    /// ```swift
    /// // Stubbing a method for any string ending with ".json"
    /// spy.when(calledWith: .endsWith(".json")).thenReturn("json_file")
    ///
    /// // Verifying a method was called with a string ending with ".txt"
    /// verify(spy.processFile(.endsWith(".txt"))).called()
    /// ```
    static func endsWith(_ suffix: String) -> Self {
        .init(precedence: .predicate) { $0.hasSuffix(suffix) }
    }

    /// A matcher that matches a string argument against a regular expression pattern.
    /// - Parameter pattern: The regular expression pattern to match.
    ///
    /// ```swift
    /// // Stubbing a method for any email address
    /// spy.when(calledWith: .matches(#"^[\w\.-]+@[\w\.-]+\.\w+$"#)).thenReturn("valid_email")
    ///
    /// // Verifying a method was called with a phone number pattern
    /// verify(spy.validate(.matches(#"\d{3}-\d{3}-\d{4}"#))).called()
    /// ```
    static func matches(_ pattern: String) -> Self {
        .init(precedence: .predicate) { string in
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(location: 0, length: string.utf16.count)
                return regex.firstMatch(in: string, options: [], range: range) != nil
            } catch {
                return false
            }
        }
    }
}

// MARK: - Result
public extension ArgMatcher {
    /// A matcher that matches a `Result.success` case using a nested matcher for the success value.
    /// - Parameter valueMatcher: An `ArgMatcher` to apply to the success value.
    static func success<T, E: Error>(_ valueMatcher: ArgMatcher<T>) -> ArgMatcher<Result<T, E>> {
        .init(precedence: valueMatcher.precedence, matcher: { result in
            switch result {
            case .success(let value):
                return valueMatcher(value)
            case .failure:
                return false
            }
        })
    }

    /// A matcher that matches a `Result.failure` case using a nested matcher for the error.
    /// - Parameter errorMatcher: An `ArgMatcher` to apply to the error value.
    static func failure<T, E>(_ errorMatcher: ArgMatcher<E>) -> ArgMatcher<Result<T, E>> {
        .init(precedence: errorMatcher.precedence, matcher: { result in
            switch result {
            case .success:
                return false
            case .failure(let err):
                return errorMatcher(err)
            }
        })
    }
}

public extension ArgMatcher {
    static func `some`<V>(_ valueMatcher: ArgMatcher<V>) -> ArgMatcher<Optional<V>> {
        .init(precedence: valueMatcher.precedence, matcher: { optional in
            switch optional {
            case .none:
                return false
            case .some(let value):
                return valueMatcher(value)
            }
        })
    }
}

// MARK: - Collection
public extension ArgMatcher where Argument: Collection {
    /// A matcher that matches an empty collection.
    ///
    /// ```swift
    /// // Stubbing a method for empty arrays
    /// spy.when(calledWith: .isEmpty()).thenReturn("no_items")
    ///
    /// // Verifying a method was called with an empty collection
    /// verify(spy.process(.isEmpty())).called()
    /// ```
    static func isEmpty() -> Self {
        .init(precedence: .predicate) { $0.isEmpty }
    }

    /// A matcher that matches a collection with a specific count.
    /// - Parameter count: The expected number of elements.
    ///
    /// ```swift
    /// // Stubbing a method for arrays with exactly 3 elements
    /// spy.when(calledWith: .hasCount(3)).thenReturn("three_items")
    ///
    /// // Verifying a method was called with a collection of 5 elements
    /// verify(spy.process(.hasCount(5))).called()
    /// ```
    static func hasCount(_ count: Int) -> Self {
        .init(precedence: .predicate) { $0.count == count }
    }

    /// A matcher that matches a collection with a count within the given range.
    /// - Parameters:
    ///   - lowerBound: The minimum count (inclusive).
    ///   - upperBound: The maximum count (inclusive).
    ///
    /// ```swift
    /// // Stubbing a method for arrays with 2-5 elements
    /// spy.when(calledWith: .hasCountBetween(2, 5)).thenReturn("medium_batch")
    /// ```
    static func hasCountBetween(_ lowerBound: Int, _ upperBound: Int) -> Self {
        .init(precedence: .predicate) { collection in
            let count = collection.count
            return count >= lowerBound && count <= upperBound
        }
    }

    /// A matcher that matches a collection with a count within a closed range.
    /// - Parameter range: A `ClosedRange<Int>` defining the acceptable count range.
    ///
    /// ```swift
    /// // Stubbing a method for arrays with 2-5 elements
    /// spy.when(calledWith: .hasCount(in: 2...5)).thenReturn("medium_batch")
    ///
    /// // Verifying a method was called with a collection of 10-20 elements
    /// verify(spy.processBatch(.hasCount(in: 10...20))).called()
    /// ```
    static func hasCount(in range: ClosedRange<Int>) -> Self {
        .init(precedence: .predicate) { range.contains($0.count) }
    }

    /// A matcher that matches a collection with a count greater than or equal to a value.
    /// - Parameter range: A `PartialRangeFrom<Int>` defining the minimum count.
    ///
    /// ```swift
    /// // Stubbing a method for arrays with at least 5 elements
    /// spy.when(calledWith: .hasCount(in: 5...)).thenReturn("large_batch")
    ///
    /// // Verifying a method was called with at least 1 element
    /// verify(spy.processItems(.hasCount(in: 1...))).called()
    /// ```
    static func hasCount(in range: PartialRangeFrom<Int>) -> Self {
        .init(precedence: .predicate) { range.contains($0.count) }
    }

    /// A matcher that matches a collection with a count less than or equal to a value.
    /// - Parameter range: A `PartialRangeThrough<Int>` defining the maximum count.
    ///
    /// ```swift
    /// // Stubbing a method for arrays with at most 10 elements
    /// spy.when(calledWith: .hasCount(in: ...10)).thenReturn("small_batch")
    ///
    /// // Verifying a method was called with at most 3 elements
    /// verify(spy.processSmallGroup(.hasCount(in: ...3))).called()
    /// ```
    static func hasCount(in range: PartialRangeThrough<Int>) -> Self {
        .init(precedence: .predicate) { range.contains($0.count) }
    }
}

public extension ArgMatcher where Argument: Collection, Argument.Element: Equatable {
    /// A matcher that matches a collection containing the given element.
    /// - Parameter element: The element to search for.
    ///
    /// ```swift
    /// // Stubbing a method for arrays containing "important"
    /// spy.when(calledWith: .contains("important")).thenReturn("found_item")
    ///
    /// // Verifying a method was called with an array containing 42
    /// verify(spy.process(.contains(42))).called()
    /// ```
    static func contains(_ element: Argument.Element) -> Self {
        .init(precedence: .predicate) { $0.contains(element) }
    }
}

// MARK: - MatcherPrecendence
public struct MatcherPrecedence: Comparable, Hashable, Sendable {
    public static let any: Self                = .init(value: 0)
    public static let typeMatch: Self          = .init(value: 100)
    public static let predicate: Self          = .init(value: 200)
    public static let equalTo: Self            = .init(value: 500)
    public static let identicalTo: Self        = .init(value: 600)
    public static let customHigh: Self         = .init(value: 700)
    public static let customExtreme: Self      = .init(value: 999)

    public var value: Int

    public init(value: Int) {
        self.value = min(value, 1000)
    }

    public static func < (lhs: MatcherPrecedence, rhs: MatcherPrecedence) -> Bool {
        lhs.value < rhs.value
    }
}
