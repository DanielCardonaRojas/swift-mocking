//
//  ArgMatcher.swift
//  Witness
//
//  Created by Daniel Cardona on 3/07/25.
//

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

public struct MatcherPrecedence: Comparable, Hashable {
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
