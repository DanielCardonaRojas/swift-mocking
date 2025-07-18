//
//  SpyAdapters.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 13/07/25.
//

// MARK: - Non Keypath variants

extension Mock {
    /// A helper that converts a spy into a closure that is easily assignable to a protocol witness closure property.
    public func adaptNone<Context: DefaultProvider, each I, O>(_ spy: Spy<repeat each I, None, O>) -> (Context, repeat each I) -> O {
        { (context, input: repeat each I) -> O  in
            spy.defaultProviderRegistry = context.defaultProviderRegistry
            let result = spy.call(repeat each input)
            return result
        }
    }

    /// A helper that converts a spy into a closure that is easily assignable to a protocol witness closure property.
    public func adaptThrows<Context: DefaultProvider, each I, O>(_ spy: Spy<repeat each I, Throws, O>) -> (Context, repeat each I) throws -> O {
        { (context, input: repeat each I) -> O  in
            spy.defaultProviderRegistry = context.defaultProviderRegistry
            let result = try spy.call(repeat each input)
            return result
        }
    }

    /// A helper that converts an `async` spy into a closure that is easily assignable to a protocol witness closure property.
    public func adaptAsync<Context: DefaultProvider, each I, O>(_ spy: Spy<repeat each I, Async, O>) -> (Context, repeat each I) async -> O {
        { (context, input: repeat each I) async -> O  in
            spy.defaultProviderRegistry = context.defaultProviderRegistry
            let result = await spy.call(repeat each input)
            return result
        }
    }

    /// A helper that converts an `async throws` spy into a closure that is easily assignable to a protocol witness closure property.
    public func adaptAsyncThrows<Context: DefaultProvider, each I, O>(
        _ spy: Spy<repeat each I, AsyncThrows, O>
    ) -> (Context, repeat each I) async throws -> O {
        { (context, input: repeat each I) async throws -> O  in
            spy.defaultProviderRegistry = context.defaultProviderRegistry
            let result = try await spy.call(repeat each input)
            return result
        }
    }

    // MARK: Static variants

    /// A helper that converts a spy into a closure that is easily assignable to a protocol witness closure property.
    public static func adaptNone<each I, O>(_ spy: Spy<repeat each I, None, O>) -> (repeat each I) -> O {
        { (input: repeat each I) -> O  in
            let result = spy.call(repeat each input)
            return result
        }
    }

    /// A helper that converts a spy into a closure that is easily assignable to a protocol witness closure property.
    public static func adaptThrows<each I, O>(_ spy: Spy<repeat each I, Throws, O>) -> (repeat each I) throws -> O {
        { (input: repeat each I) -> O  in
            let result = try spy.call(repeat each input)
            return result
        }
    }

    /// A helper that converts an `async` spy into a closure that is easily assignable to a protocol witness closure property.
    public static func adaptAsync<each I, O>(_ spy: Spy<repeat each I, Async, O>) -> (repeat each I) async -> O {
        { (input: repeat each I) async -> O  in
            let result = await spy.call(repeat each input)
            return result
        }
    }
    public static func adaptAsyncThrows<each I, O>(
        _ spy: Spy<repeat each I, AsyncThrows, O>
    ) -> (repeat each I) async throws -> O {
        { (input: repeat each I) async throws -> O  in
            let result = try await spy.call(repeat each input)
            return result
        }
    }
}
