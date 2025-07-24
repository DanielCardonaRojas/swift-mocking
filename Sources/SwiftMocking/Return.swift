//
//  Return.swift
//  Mockable
//
//  Created by Daniel Cardona on 6/07/25.
//

/// A type that represents a value that can be returned from a stubbed method.
///
/// A ``Return`` can either be a success value or an error. This is used to model the fact that a stubbed method can either return a value or throw an error.
///
/// ### Usage Example:
///
/// ```swift
/// // Creating a Return instance with a success value
/// let successReturn = Return.value(42)
/// do {
///     let result = try successReturn.get()
///     print("Success: \(result)") // Prints "Success: 42"
/// } catch {
///     // Should not be reached
/// }
///
/// // Creating a Return instance with an error
/// enum MyError: Error { case testError }
/// let errorReturn = Return<Int>.error(MyError.testError)
/// do {
///     _ = try errorReturn.get()
/// } catch let error as MyError {
///     print("Error: \(error)") // Prints "Error: testError"
/// } catch {
///     // Should not be reached
/// }
/// ```
struct Return<R> {
    typealias Deferred<V> = () -> Result<V, any Error>

    var value: Deferred<R>

    /// Initializes a `Return` instance with a deferred result.
    /// - Parameter value: A closure that returns a `Result` containing either the success value or an error.
    init(value: @escaping Deferred<R>) {
        self.value = value
    }

    /// Creates a `Return` instance that represents an error.
    /// - Parameter error: The error to be returned.
    /// - Returns: A `Return` instance encapsulating the error.
    static func error<E: Error>(_ error: E) -> Return<R> {
        Return(value: { .failure(error) })
    }

    /// Creates a `Return` instance that represents a success value.
    /// - Parameter value: The success value to be returned.
    /// - Returns: A `Return` instance encapsulating the success value.
    static func value(_ value: R) -> Return<R> {
        Return(value: { .success(value) })
    }

    /// Retrieves the encapsulated value or throws the encapsulated error.
    /// - Returns: The success value.
    /// - Throws: The encapsulated error if the `Return` instance represents an error.
    @discardableResult
    func get() throws -> R {
        try value().get()
    }
}

