//
//  SpyAdapters.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 16/09/25.
//


// MARK: Void cases - Workaround for current parameter pack extension limitations
public func adapt<Output>(_ spy: Spy<Void, Async, Output>) -> @Sendable () async ->  Output {
    { await spy.call(()) }
}

public func adapt<Output>(_ spy: Spy<Void, AsyncThrows, Output>) -> @Sendable () async throws ->  Output {
    { try await spy.call(()) }
}

public func adapt<Output>(_ spy: Spy<Void, Throws, Output>) -> @Sendable () throws ->  Output {
    { try spy.call(()) }
}

public func adapt<Output>(_ spy: Spy<Void, None, Output>) -> @Sendable () ->  Output {
    { spy.call(()) }
}

// MARK:  asFunction wrappers (to keep a consistent API)

public func adapt<each Input, Output>(_ spy: Spy<repeat each Input, Async, Output>) -> @Sendable (repeat each Input) async ->  Output {
    spy.asFunction()
}
public func adapt<each Input, Output>(_ spy: Spy<repeat each Input, Throws, Output>) -> @Sendable (repeat each Input) throws ->  Output {
    spy.asFunction()
}
public func adapt<each Input, Output>(_ spy: Spy<repeat each Input, AsyncThrows, Output>) -> @Sendable (repeat each Input) async throws ->  Output {
    spy.asFunction()
}

public func adapt<each Input, Output>(_ spy: Spy<repeat each Input, None, Output>) -> @Sendable (repeat each Input) ->  Output {
    spy.asFunction()
}


