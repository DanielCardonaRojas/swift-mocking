//
//  NonSendableFixturesTests.swift
//  SwiftMockingTests
//
//  Locks in the documented workarounds for mocking non-Sendable types under the
//  Mandatory @Sendable policy (see SWIFT6_AUDIT.md section 4):
//  - construct non-Sendable values inside handler closures instead of capturing them
//  - match non-Sendable arguments via .any / .any(that:) with Sendable captures
//    (e.g. ObjectIdentifier)
//  - the default-value fallback stays available for non-Sendable return types
//

import XCTest
@testable import SwiftMocking

/// A deliberately non-Sendable payload: a class with mutable state.
final class NonSendableMessage {
    let id = UUID()
    var body: String = "payload"
}
struct NonSendableReceipt {
    let code: Int
}

struct NonSendableValidationError: Error {
    let reason: String
}

@Mockable
protocol LegacyService {
    func send(_ message: NonSendableMessage) -> NonSendableReceipt
    func makeMessage(seed: Int) -> NonSendableMessage
    func validate(_ token: String) throws -> String
}

final class NonSendableFixturesTests: XCTestCase {
    func test_stubNonSendableReturnByConstructingItInsideHandler() {
        let mock = MockLegacyService()
        when(mock.send(.any)).thenReturn { _ in NonSendableReceipt(code: 42) }

        let receipt = mock.send(NonSendableMessage())

        XCTAssertEqual(receipt.code, 42)
        verify(mock.send(.any)).called()
    }

    func test_matchNonSendableArgumentByIdentity() {
        let mock = MockLegacyService()
        let target = NonSendableMessage()
        // UUID is Sendable; capturing the instance itself is not allowed.
        let targetID = target.id
        when(mock.send(.any(that: { $0.id == targetID }))).thenReturn { _ in NonSendableReceipt(code: 7) }

        XCTAssertEqual(mock.send(target).code, 7)
        verify(mock.send(.any(that: { $0.id == targetID }))).called()
    }

    func test_defaultValueFallbackStillAvailableForNonSendableReturns() {
        let mock = MockLegacyService()
        var registry = DefaultProvidableRegistry.default
        registry.register(DefaultProviding(NonSendableMessage.self, create: { NonSendableMessage() }))
        mock.defaultProviderRegistry = registry

        let made = mock.makeMessage(seed: 0)

        XCTAssertNotNil(made)
        verify(mock.makeMessage(seed: .any)).called()
    }

    func test_throwNonSendableErrorConstructedInsideHandler() {
        let mock = MockLegacyService()
        when(mock.validate(.any)).thenReturn { _ in throw NonSendableValidationError(reason: "invalid") }

        XCTAssertThrowsError(try mock.validate("token"))
    }
}
