//
//  Swift5CompatTests.swift
//  SwiftMocking
//
//  Consumer-compatibility lane: this target deliberately builds in Swift 5 language mode
//  and imports the Swift 6 mode library WITHOUT @testable, so it exercises exactly what a
//  Swift 5 consumer sees. @Sendable closure-capture violations surface as warnings here,
//  not errors; Sendable constraints in signatures are enforced in every mode.
//

import XCTest
import SwiftMocking

@Mockable
protocol CompatGreetingService {
    func greet(_ name: String) -> String
    func fetchCount(for id: String) async throws -> Int
}

@Mockable
protocol CompatInitializerService {
    init(value: Int)
}

/// An `Actor`-inheriting protocol, mocked as an `actor` with `nonisolated`
/// members.
///
/// Swift 5 language mode is the lane where the isolation spellings are most
/// likely to differ, so this pins that the generated shape — `nonisolated` on
/// instance members, nothing added to statics, no `final`, no restated
/// `Sendable` — still builds for a Swift 5 consumer.
@Mockable
protocol CompatActorService: Actor {
    func ping() -> Bool
    static func reset()
}

/// A deliberately non-Sendable value.
final class CompatSession {
    let token = "opaque"
}

final class Swift5CompatTests: XCTestCase {
    func testStubInvokeVerify() {
        let mock = MockCompatGreetingService()
        when(mock.greet(.any)).thenReturn("hello")

        XCTAssertEqual(mock.greet("world"), "hello")
        verify(mock.greet(.equal("world"))).called()
    }

    func testAsyncThrowingStub() async throws {
        let mock = MockCompatGreetingService()
        when(mock.fetchCount(for: .any)).thenReturn(42)

        let count = try await mock.fetchCount(for: "abc")

        XCTAssertEqual(count, 42)
        verify(mock.fetchCount(for: .equal("abc"))).called()
    }

    /// The generated initializer binds its spy to an explicitly spelled `Spy<…>`
    /// type. Swift 5 mode is the lane where inference is most likely to differ,
    /// so this pins that the annotation is enough there too.
    func testInitializerRequirementRecords() {
        MockCompatInitializerService.clear()

        _ = MockCompatInitializerService(value: 5)

        verify(MockCompatInitializerService.`init`(value: .equal(5))).called(1)
    }

    func testInitializerMockRemainsDefaultConstructible() {
        MockCompatInitializerService.clear()

        _ = MockCompatInitializerService()

        verify(MockCompatInitializerService.`init`(value: .any)).called(0)
    }

    func testSendableClosureCaptureDegradesToWarning() {
        // In Swift 5 language mode, capturing non-Sendable state in a handler closure is
        // a warning, not an error. This test pins that degradation: if it ever stops
        // compiling, the Swift 5 consumer story has regressed.
        let mock = MockCompatGreetingService()
        let session = CompatSession()
        when(mock.greet(.any)).thenReturn { _ in session.token }

        XCTAssertTrue(mock.greet("x").hasPrefix("opaque"))
    }

    /// Deliberately not `async`: a synchronous body is what proves the actor
    /// mock's members are `nonisolated` in Swift 5 mode too. An isolated witness
    /// would compile and fail only here.
    func testActorMockStubsSynchronously() {
        let mock = MockCompatActorService()
        when(mock.ping()).thenReturn(true)

        let result: Bool = mock.ping()

        XCTAssertTrue(result)
        verify(mock.ping()).called(1)
    }

    func testActorMockStaticRequirement() {
        MockCompatActorService.clear()

        // Annotated to select the conformance witness over the same-named
        // interaction builder, which is also zero-argument.
        let call: () -> Void = MockCompatActorService.reset
        call()

        verify(MockCompatActorService.reset()).called(1)
    }
}
