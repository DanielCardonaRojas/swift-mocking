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
    let matcher: (Argument) -> Bool

    public init(matcher: @escaping (Argument) -> Bool) {
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
        return .init { _ in true }
    }

    public static func any<T>(_ type: T.Type) -> ArgMatcher<T> {
        return .init { _ in true }
    }

    public static func any(that predicate: @escaping (Argument) -> Bool) -> Self {
        return .init(matcher: predicate)
    }

    /// A matcher that matches an argument if it can be cast to a specific type.
    ///
    /// This is useful when dealing with protocols or superclasses, and you want to match a specific concrete type.
    /// For example casting an argument of type: `any CustomStringConvertible` to  `String`.
    ///
    /// - Parameter type: The type to check for casting.
    /// - Returns: An `ArgMatcher` that matches if the argument can be cast to the given type.
    public static func `as`<T>(_ type: T.Type) -> Self {
        .init(matcher: { argument in
            (argument as? T) != nil
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
        .init { $0 == value }
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
        .init { $0 < value }
    }

    /// A matcher that matches an argument greater than the given value.
    /// - Parameter value: The value to compare against.
    ///
    /// ```swift
    /// // Verifying a method was called with an integer argument greater than 100
    /// verify(spy.processValue(.greaterThan(100))).called()
    /// ```
    static func greaterThan(_ value: Argument) -> Self {
        .init { $0 > value }
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
        .init { $0 === value }
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
        .init { $0 != nil }
    }

    /// A matcher that matches a nil optional argument.
    ///
    /// ```swift
    /// // Stubbing a method to return a default value when called with a nil optional integer
    /// spy.when(calledWith: .nil()).thenReturn(0)
    /// ```
    static func `nil`<T>() -> Self where Argument == Optional<T> {
        .init { $0 == nil }
    }

    /// A matcher that matches any `Error` type.
    ///
    /// ```swift
    /// // Verifying a method threw any error
    /// verify(spy.performAction()).throws(.anyError())
    /// ```
    static func anyError() -> Self {
        .init { $0 as? Error != nil }
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
        .init { $0 as? E != nil }
    }
}

// MARK: - Custom types
public extension ArgMatcher {
    static func any<Property: Equatable>(where keyPath: KeyPath<Argument, Property>, _ value: Property) -> Self {
        .init { $0[keyPath: keyPath] == value }
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
