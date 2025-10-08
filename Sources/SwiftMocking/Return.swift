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
/// let successReturn = Return<None, Int>.value(42)
/// let result = successReturn.get()
/// print("Success: \(result)") // Prints "Success: 42"
///
/// // Creating a Return instance with an error
/// enum MyError: Error { case testError }
/// let errorReturn = Return<Throws, Int>.error(MyError.testError)
/// do {
///     _ = try errorReturn.get()
/// } catch let error as MyError {
///     print("Error: \(error)") // Prints "Error: testError"
/// } catch {
///     // Should not be reached
/// }
/// ```
struct Return<Effects: Effect, R> {
    typealias ThrowingDeferred<V> = () -> Result<V, any Error>
    typealias AsyncDeferred<V> = () async -> Result<V, any Error>

    private let resolver: ThrowingDeferred<R>?
    private let asyncResolver: AsyncDeferred<R>?

    /// Initializes a `Return` instance with a deferred result.
    /// - Parameter value: A closure that returns a `Result` containing either the success value or an error.
    init(value: @escaping ThrowingDeferred<R>) {
        self.resolver = value
        self.asyncResolver = nil
    }

    /// Initializes a `Return` instance with an asynchronous deferred result.
    /// - Parameter value: An async closure that returns a `Result` containing either the success value or an error.
    init(asyncValue value: @escaping AsyncDeferred<R>) {
        self.resolver = nil
        self.asyncResolver = value
    }

    /// Creates a `Return` instance that represents a success value.
    /// - Parameter value: The success value to be returned.
    /// - Returns: A `Return` instance encapsulating the success value.
    static func value(_ value: R) -> Return<Effects, R> {
        if Effects.self is Asynchronous.Type {
            return Return(asyncValue: { .success(value) })
        }
        return Return(value: { .success(value) })
    }

    /// Resolves the deferred value into a `Result`.
    /// - Returns: The stored result for this return value.
    func resolve() -> Result<R, any Error> {
        guard let resolver else {
            fatalError("Attempted to synchronously resolve an asynchronous return.")
        }
        return resolver()
    }

    /// Attempts to resolve the value synchronously if a synchronous resolver exists.
    /// - Returns: The stored result if a synchronous resolver is present, otherwise `nil`.
    func resolveIfSynchronous() -> Result<R, any Error>? {
        resolver?()
    }

    /// Resolves the deferred value asynchronously into a `Result`.
    /// - Returns: The stored result for this return value.
    func resolveAsync() async -> Result<R, any Error> {
        if let asyncResolver {
            return await asyncResolver()
        }
        if let resolver {
            return resolver()
        }
        fatalError("Return has no resolver.")
    }
}

extension Return where Effects == None {
    /// Retrieves the encapsulated value, crashing if an error was stored.
    /// - Returns: The success value.
    func get() -> R {
        switch resolve() {
        case .success(let value):
            return value
        case .failure(let error):
            fatalError("Unexpected error for non-throwing return: \(error)")
        }
    }

    /// Creates a `Return` from a synchronous closure.
    /// - Parameter producer: A closure that produces the value.
    init(_ producer: @escaping () -> R) {
        self.init(value: { .success(producer()) })
    }
}

extension Return where Effects == Throws {
    /// Creates a `Return` instance that represents an error.
    /// - Parameter error: The error to be returned.
    /// - Returns: A `Return` instance encapsulating the error.
    static func error<E: Error>(_ error: E) -> Return<Effects, R> {
        return Return(value: { .failure(error) })
    }

    /// Creates a `Return` from a throwing synchronous closure.
    /// - Parameter producer: A closure that can throw and produces the value.
    init(_ producer: @escaping () throws -> R) {
        self.init(value: {
            do {
                return .success(try producer())
            } catch {
                return .failure(error)
            }
        })
    }

    /// Retrieves the encapsulated value or throws the encapsulated error.
    /// - Returns: The success value.
    /// - Throws: The encapsulated error if the `Return` instance represents an error.
    @discardableResult
    func get() throws -> R {
        try resolve().get()
    }
}

extension Return where Effects == Async {
    /// Retrieves the encapsulated value asynchronously, crashing if an error was stored.
    /// - Returns: The success value.
    func get() async -> R {
        switch await resolveAsync() {
        case .success(let value):
            return value
        case .failure(let error):
            fatalError("Unexpected error for non-throwing async return: \(error)")
        }
    }

    /// Creates a `Return` from an asynchronous closure.
    /// - Parameter producer: An async closure that produces the value.
    init(_ producer: @escaping () async -> R) {
        self.init(asyncValue: { .success(await producer()) })
    }
}

extension Return where Effects == AsyncThrows {
    /// Creates a `Return` instance that represents an error.
    /// - Parameter error: The error to be returned.
    /// - Returns: A `Return` instance encapsulating the error.
    static func error<E: Error>(_ error: E) -> Return<Effects, R> {
        Return(asyncValue: { .failure(error) })
    }

    /// Creates a `Return` from an asynchronous throwing closure.
    /// - Parameter producer: An async closure that can throw and produces the value.
    init(_ producer: @escaping () async throws -> R) {
        self.init(asyncValue: {
            do {
                return .success(try await producer())
            } catch {
                return .failure(error)
            }
        })
    }

    /// Retrieves the encapsulated value asynchronously or throws the encapsulated error.
    /// - Returns: The success value.
    /// - Throws: The encapsulated error if the `Return` instance represents an error.
    @discardableResult
    func get() async throws -> R {
        try await resolveAsync().get()
    }
}
