//
//  Mock+Adapters.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 20/07/25.
//

public extension Mock {
    static func adapting<each I, O>(_ spy: Spy<repeat each I, None, O>, _ input: repeat each I) -> O {
        spy.defaultProviderRegistry = defaultProviderRegistry
        let result = spy.call(repeat each input)
        return result
    }

    func adapting<each I, O>(_ spy: Spy<repeat each I, None, O>, _ input: repeat each I) -> O {
        spy.defaultProviderRegistry = defaultProviderRegistry
        let result = spy.call(repeat each input)
        return result
    }

    static func adapting<each I, O>(_ spy: Spy<repeat each I, Async, O>, _ input: repeat each I) async -> O {
        spy.defaultProviderRegistry = defaultProviderRegistry
        let result = await spy.call(repeat each input)
        return result
    }

    func adapting<each I, O>(_ spy: Spy<repeat each I, Async, O>, _ input: repeat each I) async -> O {
        spy.defaultProviderRegistry = defaultProviderRegistry
        let result = await spy.call(repeat each input)
        return result
    }

    static func adaptThrowing<each I, O>(_ spy: Spy<repeat each I, Throws, O>, _ input: repeat each I) throws -> O {
        spy.defaultProviderRegistry = defaultProviderRegistry
        let result = try spy.call(repeat each input)
        return result
    }

    func adaptThrowing<each I, O>(_ spy: Spy<repeat each I, Throws, O>, _ input: repeat each I) throws -> O {
        spy.defaultProviderRegistry = defaultProviderRegistry
        let result = try spy.call(repeat each input)
        return result
    }

    static func adaptThrowing<each I, O>(_ spy: Spy<repeat each I, AsyncThrows, O>, _ input: repeat each I) async throws -> O {
        spy.defaultProviderRegistry = defaultProviderRegistry
        let result = try await spy.call(repeat each input)
        return result
    }

    public func adaptThrowing<each I, O>(_ spy: Spy<repeat each I, AsyncThrows, O>, _ input: repeat each I) async throws -> O {
        spy.defaultProviderRegistry = defaultProviderRegistry
        let result = try await spy.call(repeat each input)
        return result
    }

}
