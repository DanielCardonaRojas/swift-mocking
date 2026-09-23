//
//  SpyAdapters.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 16/09/25.
//


// MARK: Void cases - Workaround for current parameter pack extension limitations
public func adapt<Output>(_ spy: Spy<Void, Async, Output>) -> @Sendable () async ->  Output where Output: Sendable {
    { await spy(()) }
}

public func adapt<Output>(_ spy: Spy<Void, AsyncThrows, Output>) -> @Sendable () async throws ->  Output where Output: Sendable {
    { try await spy(()) }
}

public func adapt<Output>(_ spy: Spy<Void, Throws, Output>) -> @Sendable () throws ->  Output where Output: Sendable {
    { try spy(()) }
}

public func adapt<Output>(_ spy: Spy<Void, None, Output>) -> @Sendable () ->  Output where Output: Sendable {
    { spy(()) }
}

// MARK:  asFunction wrappers (to keep a consistent API)

public func adapt<each Input, Output>(_ spy: Spy<repeat each Input, Async, Output>) -> @Sendable (repeat each Input) async ->  Output where repeat each Input: Sendable, Output: Sendable {
    spy.asFunction()
}
public func adapt<each Input, Output>(_ spy: Spy<repeat each Input, Throws, Output>) -> @Sendable (repeat each Input) throws ->  Output where repeat each Input: Sendable, Output: Sendable {
    spy.asFunction()
}
public func adapt<each Input, Output>(_ spy: Spy<repeat each Input, AsyncThrows, Output>) -> @Sendable (repeat each Input) async throws ->  Output where repeat each Input: Sendable, Output: Sendable {
    spy.asFunction()
}

public func adapt<each Input, Output>(_ spy: Spy<repeat each Input, None, Output>) -> @Sendable (repeat each Input) ->  Output where repeat each Input: Sendable, Output: Sendable {
    spy.asFunction()
}


