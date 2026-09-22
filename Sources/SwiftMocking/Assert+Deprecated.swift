//
//  Assert+Deprecated.swift
//  SwiftMocking
//
//  Deprecated spellings kept for source compatibility. Delete this file in the
//  next major release.
//

// MARK: - `throws(_:)`
//
// Superseded by `didThrow(_:)`: the old name needed backticks to avoid the
// keyword, and read as a present-tense claim about an invocation that has
// already been recorded.

public extension Assert where Eff == Throws {
    @available(*, deprecated, renamed: "didThrow(_:fileID:file:line:column:)", message: "Renamed to didThrow(_:).")
    func `throws`(
        _ errorMatcher: ArgMatcher<any Error>? = nil,
        fileID: StaticString = #fileID,
        file: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) {
        didThrow(errorMatcher, fileID: fileID, file: file, line: line, column: column)
    }
}

public extension Assert where Eff == AsyncThrows {
    @available(*, deprecated, renamed: "didThrow(_:fileID:file:line:column:)", message: "Renamed to didThrow(_:).")
    func `throws`(
        _ errorMatcher: ArgMatcher<any Error>? = nil,
        fileID: StaticString = #fileID,
        file: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) async {
        await didThrow(errorMatcher, fileID: fileID, file: file, line: line, column: column)
    }
}

public extension Assert where Eff: SyncTypedThrowingEffect {
    @available(*, deprecated, renamed: "didThrow(_:fileID:file:line:column:)", message: "Renamed to didThrow(_:).")
    func `throws`(
        _ errorMatcher: ArgMatcher<Eff.Failure> = .any(Eff.Failure.self),
        fileID: StaticString = #fileID,
        file: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) {
        didThrow(errorMatcher, fileID: fileID, file: file, line: line, column: column)
    }
}

public extension Assert where Eff: AsyncTypedThrowingEffect {
    @available(*, deprecated, renamed: "didThrow(_:fileID:file:line:column:)", message: "Renamed to didThrow(_:).")
    func `throws`(
        _ errorMatcher: ArgMatcher<Eff.Failure> = .any(Eff.Failure.self),
        fileID: StaticString = #fileID,
        file: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) async {
        await didThrow(errorMatcher, fileID: fileID, file: file, line: line, column: column)
    }
}

// MARK: - `doesThrow(_:)`
//
// Superseded by `didThrow(_:)`, which also no longer requires `try`: a failed
// verification reports an issue at the call site like every other assertion,
// rather than throwing an error the test has to propagate.

public extension Assert where Eff == Throws {
    @available(*, deprecated, renamed: "didThrow(_:fileID:file:line:column:)", message: "Renamed to didThrow(_:), which reports the failure instead of throwing — drop the `try`.")
    func doesThrow(_ errorMatcher: ArgMatcher<any Error>? = nil) throws {
        try assertThrew(errorMatcher)
    }
}

public extension Assert where Eff == AsyncThrows {
    @available(*, deprecated, renamed: "didThrow(_:fileID:file:line:column:)", message: "Renamed to didThrow(_:), which reports the failure instead of throwing — drop the `try`.")
    func doesThrow(_ errorMatcher: ArgMatcher<any Error>? = nil) async throws {
        try await assertThrew(errorMatcher)
    }
}

public extension Assert where Eff: SyncTypedThrowingEffect {
    @available(*, deprecated, renamed: "didThrow(_:fileID:file:line:column:)", message: "Renamed to didThrow(_:), which reports the failure instead of throwing — drop the `try`.")
    func doesThrow(_ errorMatcher: ArgMatcher<Eff.Failure> = .any(Eff.Failure.self)) throws {
        try assertThrew(errorMatcher)
    }
}

public extension Assert where Eff: AsyncTypedThrowingEffect {
    @available(*, deprecated, renamed: "didThrow(_:fileID:file:line:column:)", message: "Renamed to didThrow(_:), which reports the failure instead of throwing — drop the `try`.")
    func doesThrow(_ errorMatcher: ArgMatcher<Eff.Failure> = .any(Eff.Failure.self)) async throws {
        try await assertThrew(errorMatcher)
    }
}
