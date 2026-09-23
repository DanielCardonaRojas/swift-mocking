//
//  NonSendableFixturesTests.swift
//  SwiftMockingTests
//
//  Locks in the documented workarounds for mocking non-Sendable types under the
//  Mandatory @Sendable policy (see README.md, "Swift 6 and Sendable"):
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
    func load(id: String) async -> NonSendableMessage
    func fetch(id: String) async throws -> NonSendableMessage
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

    // MARK: - Conditional Sendable conformances

    func test_asyncRequirementsReturningNonSendableValues() async throws {
        let mock = MockLegacyService()
        when(mock.load(id: .any)).thenReturn { _ in NonSendableMessage() }
        when(mock.fetch(id: .any)).thenReturn { _ in NonSendableMessage() }

        let loaded = await mock.load(id: "a")
        let fetched = try await mock.fetch(id: "b")

        XCTAssertEqual(loaded.body, "payload")
        XCTAssertEqual(fetched.body, "payload")
        verify(mock.load(id: .any)).called()
        verify(mock.fetch(id: .any)).called()
    }

    func test_generatedMockOfNonSendableProtocolIsStillSendable() {
        // The headline guarantee for consumers: making Spy, Stub and Interaction
        // conditionally Sendable did not stop a *mock* from crossing isolation
        // domains, because a generated mock stores a `Mock`, which never names the
        // protocol's input or output types. Compile-time proof.
        let mock = MockLegacyService()

        let sendable: any Sendable = mock
        let closure: @Sendable () -> Void = { _ = mock }

        _ = (sendable, closure)
    }

    func test_closureInjectionOfNonSendableOutput() {
        // `adapt` and `asFunction` come in @Sendable and plain forms. The plain form
        // carries no constraints, so a spy over a non-Sendable type is still injectable
        // as a function; overload resolution picks it from the contextual type. Asking
        // for a @Sendable closure over the same spy still fails, which is the point.
        class UserProfile {
            let name: String
            init(name: String) {
                self.name = name
            }
        }
        let spy = Spy<String, None, UserProfile>()
        when(spy(.any)).thenReturn { _ in UserProfile(name: "Daniel") }

        let inject: (String) -> UserProfile = adapt(spy)
        XCTAssertEqual(inject("").name, "Daniel")
        verify(spy(.any)).called()
    }

    func test_untilAcceptsRequirementReturningNonSendableValue() async throws {
        // `until` waits for a call without touching its return value, so a
        // non-Sendable Output must not block it. Asserts the timeout path because a
        // spy over a non-Sendable Output is itself not Sendable, and so cannot be
        // driven from a second task.
        let mock = MockLegacyService()
        when(mock.load(id: .any)).thenReturn { _ in NonSendableMessage() }

        do {
            try await until(mock.load(id: .equal("never")), timeout: .milliseconds(50))
            XCTFail("Expected a timeout")
        } catch let error as UntilError {
            guard case .timeout = error else {
                return XCTFail("Expected .timeout, got \(error)")
            }
        }
    }
}
