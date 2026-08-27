//
//  CompositionStaticScopeTests.swift
//  swift-mocking
//

import Testing
import SwiftMocking

#if swift(>=6.1)

@Mockable([.composition])
protocol ScopedLogger {
    static func log(_ message: String)
}

@Mockable([.composition])
protocol OtherScopedLogger {
    static func log(_ message: String)
}

/// Static spies on composed mocks must participate in ``MockScope`` isolation.
///
/// A composed mock reaches its static requirements through a `Mock` *instance*
/// (`staticMock`), not through `Mock`'s static subscript. That instance used to
/// keep spies in private per-instance storage, so `.mocking` — which isolates by
/// swapping `MockScope.storageProvider` — had no effect on them: invocations
/// leaked between tests and would race under parallel execution, the exact
/// problem `MockScope` exists to prevent.
///
/// The generated `staticMock` now carries the mock's own type name as its
/// scoped storage key, putting its spies in the same place, under the same
/// identity, as an inheriting mock's static spies.
@Suite(.serialized)
struct CompositionStaticScopeTests {
    /// Records an invocation that the next test must not see.
    @Test(.mocking)
    func aRecordsAnInvocation() {
        let logger: ScopedLogger.Type = MockScopedLogger.self

        logger.log("first")

        verify(MockScopedLogger.log(.any)).called(1)
    }

    /// Runs in a fresh `.mocking` scope. Before the fix this failed, seeing the
    /// invocation recorded by the previous test.
    @Test(.mocking)
    func bStartsWithACleanScope() {
        verifyNever(MockScopedLogger.log(.any))
    }

    /// Each composed mock gets its own storage bucket — keying every one under
    /// a shared identity would make them share spies.
    @Test(.mocking)
    func distinctMocksDoNotShareStorage() {
        let logger: ScopedLogger.Type = MockScopedLogger.self

        logger.log("only mine")

        verify(MockScopedLogger.log(.any)).called(1)
        verifyNever(MockOtherScopedLogger.log(.any))
    }

    /// The static `clear()` clears only its own mock's static spies.
    @Test(.mocking)
    func staticClearIsScopedToOneMock() {
        let mine: ScopedLogger.Type = MockScopedLogger.self
        let theirs: OtherScopedLogger.Type = MockOtherScopedLogger.self
        mine.log("mine")
        theirs.log("theirs")

        MockScopedLogger.clear()

        verifyNever(MockScopedLogger.log(.any))
        verify(MockOtherScopedLogger.log(.any)).called(1)
    }
}

#endif
