//
//  SpyAdapters.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 13/07/25.
//

/// A helper that converts a spy into a closure that is easily assignable to a protocol witness closure property.
public func adapt<Context: DefaultProvider, each I, O>(_ keyPath: KeyPath<Context, Spy<repeat each I, None, O>>) -> (Context, repeat each I) -> O {
    { (context, input: repeat each I) -> O  in
        let spy = context[keyPath: keyPath]
        spy.defaultProviderRegistry = context.defaultProviderRegistry
        let result = spy.call(repeat each input)
        return result
    }
}

/// A helper that converts a spy into a closure that is easily assignable to a protocol witness closure property.
public func adapt<Context: DefaultProvider, each I, O>(_ keyPath: KeyPath<Context, Spy<repeat each I, Throws, O>>) -> (Context, repeat each I) throws -> O {
    { (context, input: repeat each I) -> O  in
        let spy = context[keyPath: keyPath]
        spy.defaultProviderRegistry = context.defaultProviderRegistry
        let result = try spy.call(repeat each input)
        return result
    }
}

/// A helper that converts an `async` spy into a closure that is easily assignable to a protocol witness closure property.
public func adapt<Context: DefaultProvider, each I, O>(_ keyPath: KeyPath<Context, Spy<repeat each I, Async, O>>) -> (Context, repeat each I) async -> O {
    { (context, input: repeat each I) async -> O  in
        let spy = context[keyPath: keyPath]
        spy.defaultProviderRegistry = context.defaultProviderRegistry
        let result = await spy.call(repeat each input)
        return result
    }
}

/// A helper that converts an `async throws` spy into a closure that is easily assignable to a protocol witness closure property.
public func adapt<Context: DefaultProvider, each I, O>(_ keyPath: KeyPath<Context, Spy<repeat each I, AsyncThrows, O>>) -> (Context, repeat each I) async throws -> O {
    { (context, input: repeat each I) async throws -> O  in
        let spy = context[keyPath: keyPath]
        spy.defaultProviderRegistry = context.defaultProviderRegistry
        let result = try await spy.call(repeat each input)
        return result
    }
}

/// A helper that converts a spy into a closure that is easily assignable to a protocol witness closure property.
public func adaptNone<Context: DefaultProvider, each I, O>(_ context: Context, _ spy: Spy<repeat each I, None, O>) -> (Context, repeat each I) -> O {
    { (context, input: repeat each I) -> O  in
        spy.defaultProviderRegistry = context.defaultProviderRegistry
        let result = spy.call(repeat each input)
        return result
    }
}

/// A helper that converts a spy into a closure that is easily assignable to a protocol witness closure property.
public func adaptThrows<Context: DefaultProvider, each I, O>(_ context: Context, _ spy: Spy<repeat each I, Throws, O>) -> (Context, repeat each I) throws -> O {
    { (context, input: repeat each I) -> O  in
        spy.defaultProviderRegistry = context.defaultProviderRegistry
        let result = try spy.call(repeat each input)
        return result
    }
}

/// A helper that converts an `async` spy into a closure that is easily assignable to a protocol witness closure property.
public func adaptAsync<Context: DefaultProvider, each I, O>(_ context: Context, _ spy: Spy<repeat each I, Async, O>) -> (Context, repeat each I) async -> O {
    { (context, input: repeat each I) async -> O  in
        spy.defaultProviderRegistry = context.defaultProviderRegistry
        let result = await spy.call(repeat each input)
        return result
    }
}

/// A helper that converts an `async throws` spy into a closure that is easily assignable to a protocol witness closure property.
public func adaptAsyncThrows<Context: DefaultProvider, each I, O>(
    _ context: Context, _ spy: Spy<repeat each I, AsyncThrows, O>
) -> (Context, repeat each I) async throws -> O {
    { (context, input: repeat each I) async throws -> O  in
        spy.defaultProviderRegistry = context.defaultProviderRegistry
        let result = try await spy.call(repeat each input)
        return result
    }
}

