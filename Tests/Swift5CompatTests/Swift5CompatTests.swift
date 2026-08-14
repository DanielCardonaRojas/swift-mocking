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

    func testSendableClosureCaptureDegradesToWarning() {
        // In Swift 5 language mode, capturing non-Sendable state in a handler closure is
        // a warning, not an error. This test pins that degradation: if it ever stops
        // compiling, the Swift 5 consumer story has regressed.
        let mock = MockCompatGreetingService()
        let session = CompatSession()
        when(mock.greet(.any)).thenReturn { _ in session.token }

        XCTAssertTrue(mock.greet("x").hasPrefix("opaque"))
    }
}
