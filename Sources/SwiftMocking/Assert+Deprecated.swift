//
//  Assert+Deprecated.swift
//  SwiftMocking
//
//  Deprecated spellings kept for source compatibility. Delete this file in the
//  next major release.
//

public extension Assert where Eff == Throws {
    @available(*, deprecated, renamed: "didThrow(_:)", message: "Renamed to didThrow(_:) to read as a past-tense assertion about a recorded invocation.")
    func doesThrow(_ errorMatcher: ArgMatcher<any Error>? = nil) throws {
        try didThrow(errorMatcher)
    }
}

public extension Assert where Eff == AsyncThrows {
    @available(*, deprecated, renamed: "didThrow(_:)", message: "Renamed to didThrow(_:) to read as a past-tense assertion about a recorded invocation.")
    func doesThrow(_ errorMatcher: ArgMatcher<any Error>? = nil) async throws {
        try await didThrow(errorMatcher)
    }
}

public extension Assert where Eff: SyncTypedThrowingEffect {
    @available(*, deprecated, renamed: "didThrow(_:)", message: "Renamed to didThrow(_:) to read as a past-tense assertion about a recorded invocation.")
    func doesThrow(_ errorMatcher: ArgMatcher<Eff.Failure> = .any(Eff.Failure.self)) throws {
        try didThrow(errorMatcher)
    }
}

public extension Assert where Eff: AsyncTypedThrowingEffect {
    @available(*, deprecated, renamed: "didThrow(_:)", message: "Renamed to didThrow(_:) to read as a past-tense assertion about a recorded invocation.")
    func doesThrow(_ errorMatcher: ArgMatcher<Eff.Failure> = .any(Eff.Failure.self)) async throws {
        try await didThrow(errorMatcher)
    }
}
