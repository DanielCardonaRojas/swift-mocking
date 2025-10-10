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
    private let syncResolver: (() -> R)?
    private let throwingResolver: (() throws -> R)?
    private let asyncResolver: (() async -> R)?
    private let asyncThrowingResolver: (() async throws -> R)?

    /// Initializes a `Return` instance with a synchronous resolver.
    init(syncValue value: @escaping () -> R) {
        self.syncResolver = value
        self.throwingResolver = nil
        self.asyncResolver = nil
        self.asyncThrowingResolver = nil
    }

    /// Initializes a `Return` instance with a throwing resolver.
    init(throwingValue value: @escaping () throws -> R) {
        self.syncResolver = nil
        self.throwingResolver = value
        self.asyncResolver = nil
        self.asyncThrowingResolver = nil
    }

    /// Initializes a `Return` instance with an asynchronous resolver.
    init(asyncValue value: @escaping () async -> R) {
        self.syncResolver = nil
        self.throwingResolver = nil
        self.asyncResolver = value
        self.asyncThrowingResolver = nil
    }

    /// Initializes a `Return` instance with an asynchronous throwing resolver.
    init(asyncThrowingValue value: @escaping () async throws -> R) {
        self.syncResolver = nil
        self.throwingResolver = nil
        self.asyncResolver = nil
        self.asyncThrowingResolver = value
    }

    /// Creates a `Return` instance that represents a success value.
    /// - Parameter value: The success value to be returned.
    /// - Returns: A `Return` instance encapsulating the success value.
    static func value(_ value: R) -> Return<Effects, R> {
        switch Effects.self {
        case is None.Type:
            return Return(syncValue: { value })
        case is Throws.Type:
            return Return(throwingValue: { value })
        case is Async.Type:
            return Return(asyncValue: { value })
        case is AsyncThrows.Type:
            return Return(asyncThrowingValue: { value })
        default:
            fatalError("Unknown effect type: \(Effects.self)")
        }
    }

}

extension Return where Effects == None {
    /// Resolves the deferred value into a `Result`.
    /// - Returns: The stored result for this return value.
    func resolve() -> Result<R, any Error> {
        guard let syncResolver else {
            fatalError("Return has no resolver.")
        }
        return .success(syncResolver())
    }

    /// Retrieves the encapsulated value, crashing if an error was stored.
    /// - Returns: The success value.
    func get() -> R {
        guard let syncResolver else {
            fatalError("Return has no resolver.")
        }
        return syncResolver()
    }

    /// Creates a `Return` from a synchronous closure.
    /// - Parameter producer: A closure that produces the value.
    init(_ producer: @escaping () -> R) {
        self.init(syncValue: producer)
    }
}

extension Return where Effects == Throws {
    /// Resolves the deferred value into a `Result`.
    /// - Returns: The stored result for this return value.
    func resolve() -> Result<R, any Error> {
        guard let throwingResolver else {
            fatalError("Return has no resolver.")
        }
        do {
            return .success(try throwingResolver())
        } catch {
            return .failure(error)
        }
    }

    /// Attempts to resolve the value synchronously if a synchronous resolver exists.
    /// - Returns: The stored result if a synchronous resolver is present, otherwise `nil`.
    func resolveIfSynchronous() -> Result<R, any Error>? {
        guard let throwingResolver else { return nil }
        do {
            return .success(try throwingResolver())
        } catch {
            return .failure(error)
        }
    }

    /// Creates a `Return` instance that represents an error.
    /// - Parameter error: The error to be returned.
    /// - Returns: A `Return` instance encapsulating the error.
    static func error<E: Error>(_ error: E) -> Return<Effects, R> {
        return Return(throwingValue: { throw error })
    }

    /// Creates a `Return` from a throwing synchronous closure.
    /// - Parameter producer: A closure that can throw and produces the value.
    init(_ producer: @escaping () throws -> R) {
        self.init(throwingValue: producer)
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
    /// Resolves the deferred value asynchronously into a `Result`.
    /// - Returns: The stored result for this return value.
    func resolveAsync() async -> Result<R, any Error> {
        guard let asyncResolver else {
            fatalError("Return has no resolver.")
        }
        return .success(await asyncResolver())
    }

    /// Retrieves the encapsulated value asynchronously, crashing if an error was stored.
    /// - Returns: The success value.
    func get() async -> R {
        guard let asyncResolver else {
            fatalError("Return has no resolver.")
        }
        return await asyncResolver()
    }

    /// Creates a `Return` from an asynchronous closure.
    /// - Parameter producer: An async closure that produces the value.
    init(_ producer: @escaping () async -> R) {
        self.init(asyncValue: producer)
    }
}

extension Return where Effects == AsyncThrows {
    /// Resolves the deferred value asynchronously into a `Result`.
    /// - Returns: The stored result for this return value.
    func resolveAsync() async -> Result<R, any Error> {
        guard let asyncThrowingResolver else {
            fatalError("Return has no resolver.")
        }
        do {
            return .success(try await asyncThrowingResolver())
        } catch {
            return .failure(error)
        }
    }

    /// Creates a `Return` instance that represents an error.
    /// - Parameter error: The error to be returned.
    /// - Returns: A `Return` instance encapsulating the error.
    static func error<E: Error>(_ error: E) -> Return<Effects, R> {
        Return(asyncThrowingValue: { throw error })
    }

    /// Creates a `Return` from an asynchronous throwing closure.
    /// - Parameter producer: An async closure that can throw and produces the value.
    init(_ producer: @escaping () async throws -> R) {
        self.init(asyncThrowingValue: producer)
    }

    /// Retrieves the encapsulated value asynchronously or throws the encapsulated error.
    /// - Returns: The success value.
    /// - Throws: The encapsulated error if the `Return` instance represents an error.
    @discardableResult
    func get() async throws -> R {
        try await resolveAsync().get()
    }
}
