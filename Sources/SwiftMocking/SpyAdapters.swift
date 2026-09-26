//
//  SpyAdapters.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 16/09/25.
//

// Each requirement has two adapters: one producing a `@Sendable` closure, and one
// producing a plain closure.
//
// A `Spy` stores its stubbed outputs, so it is only `Sendable` when its inputs and
// output are. Handing out a `@Sendable` closure that captures the spy therefore needs
// those constraints — without them a non-`Sendable` value could cross isolation domains.
//
// A plain closure carries no such risk and needs no constraints, which is what lets a
// spy over a non-`Sendable` type still be injected as a function:
//
//     let spy = Spy<String, None, UserProfile>()   // UserProfile is a class
//     let inject: (String) -> UserProfile = adapt(spy)
//
// Overload resolution picks whichever matches the contextual type, so asking for a
// `@Sendable` closure over non-`Sendable` types still fails — correctly, since that
// conversion is the data race the constraints exist to prevent.

// MARK: Void cases - Workaround for current parameter pack extension limitations
public func adapt<Output>(
    _ spy: Spy<Void, Async, Output>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) -> @Sendable () async ->  Output where Output: Sendable {
    { await spy((), fileID: fileID, filePath: filePath, line: line, column: column) }
}

public func adapt<Output>(
    _ spy: Spy<Void, Async, Output>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) -> () async ->  Output {
    { await spy((), fileID: fileID, filePath: filePath, line: line, column: column) }
}

public func adapt<Output>(
    _ spy: Spy<Void, AsyncThrows, Output>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) -> @Sendable () async throws ->  Output where Output: Sendable {
    { try await spy((), fileID: fileID, filePath: filePath, line: line, column: column) }
}

public func adapt<Output>(
    _ spy: Spy<Void, AsyncThrows, Output>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) -> () async throws ->  Output {
    { try await spy((), fileID: fileID, filePath: filePath, line: line, column: column) }
}

public func adapt<Output>(
    _ spy: Spy<Void, Throws, Output>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) -> @Sendable () throws ->  Output where Output: Sendable {
    { try spy((), fileID: fileID, filePath: filePath, line: line, column: column) }
}

public func adapt<Output>(
    _ spy: Spy<Void, Throws, Output>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) -> () throws ->  Output {
    { try spy((), fileID: fileID, filePath: filePath, line: line, column: column) }
}

public func adapt<Output>(
    _ spy: Spy<Void, None, Output>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) -> @Sendable () ->  Output where Output: Sendable {
    { spy((), fileID: fileID, filePath: filePath, line: line, column: column) }
}

public func adapt<Output>(
    _ spy: Spy<Void, None, Output>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) -> () ->  Output {
    { spy((), fileID: fileID, filePath: filePath, line: line, column: column) }
}

// MARK:  asFunction wrappers (to keep a consistent API)

public func adapt<each Input, Output>(
    _ spy: Spy<repeat each Input, Async, Output>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) -> @Sendable (repeat each Input) async ->  Output where repeat each Input: Sendable, Output: Sendable {
    spy.asFunction(fileID: fileID, filePath: filePath, line: line, column: column)
}

public func adapt<each Input, Output>(
    _ spy: Spy<repeat each Input, Async, Output>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) -> (repeat each Input) async ->  Output {
    spy.asFunction(fileID: fileID, filePath: filePath, line: line, column: column)
}

public func adapt<each Input, Output>(
    _ spy: Spy<repeat each Input, Throws, Output>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) -> @Sendable (repeat each Input) throws ->  Output where repeat each Input: Sendable, Output: Sendable {
    spy.asFunction(fileID: fileID, filePath: filePath, line: line, column: column)
}

public func adapt<each Input, Output>(
    _ spy: Spy<repeat each Input, Throws, Output>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) -> (repeat each Input) throws ->  Output {
    spy.asFunction(fileID: fileID, filePath: filePath, line: line, column: column)
}

public func adapt<each Input, Output>(
    _ spy: Spy<repeat each Input, AsyncThrows, Output>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) -> @Sendable (repeat each Input) async throws ->  Output where repeat each Input: Sendable, Output: Sendable {
    spy.asFunction(fileID: fileID, filePath: filePath, line: line, column: column)
}

public func adapt<each Input, Output>(
    _ spy: Spy<repeat each Input, AsyncThrows, Output>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) -> (repeat each Input) async throws ->  Output {
    spy.asFunction(fileID: fileID, filePath: filePath, line: line, column: column)
}

public func adapt<each Input, Output>(
    _ spy: Spy<repeat each Input, None, Output>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) -> @Sendable (repeat each Input) ->  Output where repeat each Input: Sendable, Output: Sendable {
    spy.asFunction(fileID: fileID, filePath: filePath, line: line, column: column)
}

public func adapt<each Input, Output>(
    _ spy: Spy<repeat each Input, None, Output>,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) -> (repeat each Input) ->  Output {
    spy.asFunction(fileID: fileID, filePath: filePath, line: line, column: column)
}
