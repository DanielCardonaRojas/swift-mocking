//
//  TypedThrowsTests.swift
//  swift-mocking
//

import XCTest
@testable import SwiftMocking
import SwiftMockingTestSupport

@Mockable
protocol TypedThrowingService {
    func load(_ id: Int) throws(TestError) -> String
    func fetch(_ id: Int) async throws(TestError) -> String
    /// `@escaping` describes how the parameter is passed, not its type. The spy's
    /// pack must drop the attribute — `Spy<@escaping () -> Void, ...>` does not parse.
    func run(_ handler: @escaping @Sendable () -> Void) throws(TestError) -> Int
}

/// End-to-end coverage for typed-throws requirements (`throws(E)`).
///
/// A typed-throws requirement carries its declared error type into the spy as
/// `TypedThrows<E>` / `AsyncTypedThrows<E>`, so the generated conformance keeps the
/// requirement's `throws(E)` signature instead of widening to `any Error`. These tests
/// pin the three consequences that matters to callers: the error survives the round
/// trip, it arrives already typed as `E` (no `as?` needed at the catch site), and
/// stubbing/verification behave as they do for untyped throws.
final class TypedThrowsTests: MockingTestCase {
    // MARK: Synchronous

    func testTypedThrows_RethrowsStubbedErrorAsDeclaredType() {
        let mock = MockTypedThrowingService()
        when(mock.load(.any)).thenThrow(.example)

        // The `catch` binds `TestError` directly: with typed throws the compiler
        // knows no other error can reach it, so there is no `as?` and no default case.
        do {
            _ = try mock.load(1)
            XCTFail("Expected load to throw")
        } catch {
            XCTAssertEqual(error, TestError.example)
        }
    }

    func testTypedThrows_ReturnsStubbedValue() throws {
        let mock = MockTypedThrowingService()
        when(mock.load(.any)).thenReturn("loaded")

        XCTAssertEqual(try mock.load(1), "loaded")
    }

    func testTypedThrows_MatcherSelectsBetweenValueAndError() {
        let mock = MockTypedThrowingService()
        when(mock.load(.equal(1))).thenReturn("one")
        when(mock.load(.equal(2))).thenThrow(.other)

        XCTAssertEqual(try? mock.load(1), "one")
        do {
            _ = try mock.load(2)
            XCTFail("Expected load(2) to throw")
        } catch {
            XCTAssertEqual(error, TestError.other)
        }
    }

    func testTypedThrows_ThrowingHandlerPropagatesDeclaredError() {
        let mock = MockTypedThrowingService()
        when(mock.load(.any)).thenReturn { (id: Int) throws(TestError) -> String in
            if id < 0 { throw .other }
            return "id-\(id)"
        }

        XCTAssertEqual(try? mock.load(3), "id-3")
        do {
            _ = try mock.load(-1)
            XCTFail("Expected load(-1) to throw")
        } catch {
            XCTAssertEqual(error, TestError.other)
        }
    }

    func testTypedThrows_VerifyAndDoesThrow() throws {
        let mock = MockTypedThrowingService()
        when(mock.load(.any)).thenThrow(.example)

        _ = try? mock.load(1)

        verify(mock.load(.equal(1))).called(1)
        verify(mock.load(.any)).didThrow(.error(TestError.self))
    }

    /// The defaulted matcher accepts any error of the declared failure type, so
    /// `didThrow()` asserts only that something was thrown.
    func testTypedThrows_DidThrowDefaultsToAnyFailure() throws {
        let mock = MockTypedThrowingService()
        when(mock.load(.any)).thenThrow(.example)

        _ = try? mock.load(1)

        verify(mock.load(.any)).didThrow()
    }

    func testTypedThrows_DidThrowFailsWhenErrorDoesNotMatch() throws {
        let mock = MockTypedThrowingService()
        when(mock.load(.any)).thenThrow(.example)

        _ = try? mock.load(1)

        // `didThrow` reports rather than throws, so the expected failure is
        // captured instead of caught.
        XCTExpectFailure("thrown .example does not match .other")
        verify(mock.load(.any)).didThrow(.equal(.other))
    }

    /// The `Equatable` shorthand compares by value, so a bare case can be passed
    /// without spelling out `.equal(_:)`.
    func testTypedThrows_DidThrowEquatableShorthand() throws {
        let mock = MockTypedThrowingService()
        when(mock.load(.any)).thenThrow(.example)

        _ = try? mock.load(1)

        verify(mock.load(.any)).didThrow(.example)
        XCTExpectFailure("thrown .example does not match .other")
        verify(mock.load(.any)).didThrow(.other)
    }

    func testTypedThrows_DidThrowFailsWhenNothingThrown() throws {
        let mock = MockTypedThrowingService()
        when(mock.load(.any)).thenReturn("ok")

        _ = try? mock.load(1)

        XCTExpectFailure("nothing was thrown")
        verify(mock.load(.any)).didThrow()
    }

    func testTypedThrows_FluentThrowsVerification() {
        let mock = MockTypedThrowingService()
        when(mock.load(.any)).thenThrow(.example)

        _ = try? mock.load(1)

        verify(mock.load(.any)).didThrow()
        verify(mock.load(.any)).didThrow(.error(TestError.self))
    }

    func testTypedThrows_EscapingClosureParameter() throws {
        let mock = MockTypedThrowingService()
        when(mock.run(.any)).thenReturn(1)

        XCTAssertEqual(try mock.run({}), 1)
        verify(mock.run(.any)).called(1)
    }

    // MARK: Asynchronous

    func testAsyncTypedThrows_RethrowsStubbedErrorAsDeclaredType() async {
        let mock = MockTypedThrowingService()
        when(mock.fetch(.any)).thenThrow(.example)

        do {
            _ = try await mock.fetch(1)
            XCTFail("Expected fetch to throw")
        } catch {
            XCTAssertEqual(error, TestError.example)
        }
    }

    func testAsyncTypedThrows_ReturnsStubbedValue() async throws {
        let mock = MockTypedThrowingService()
        when(mock.fetch(.any)).thenReturn("fetched")

        let value = try await mock.fetch(1)
        XCTAssertEqual(value, "fetched")
    }

    func testAsyncTypedThrows_AsyncThrowingHandlerPropagatesDeclaredError() async {
        let mock = MockTypedThrowingService()
        when(mock.fetch(.any)).thenReturn { (id: Int) async throws(TestError) -> String in
            if id < 0 { throw .other }
            return "id-\(id)"
        }

        let value = try? await mock.fetch(3)
        XCTAssertEqual(value, "id-3")

        do {
            _ = try await mock.fetch(-1)
            XCTFail("Expected fetch(-1) to throw")
        } catch {
            XCTAssertEqual(error, TestError.other)
        }
    }

    func testAsyncTypedThrows_FluentThrowsVerification() async {
        let mock = MockTypedThrowingService()
        when(mock.fetch(.any)).thenThrow(.example)

        _ = try? await mock.fetch(1)

        await verify(mock.fetch(.any)).didThrow()
        await verify(mock.fetch(.any)).didThrow(.error(TestError.self))
    }

    func testAsyncTypedThrows_VerifyAndDoesThrow() async throws {
        let mock = MockTypedThrowingService()
        when(mock.fetch(.any)).thenThrow(.example)

        _ = try? await mock.fetch(1)

        verify(mock.fetch(.equal(1))).called(1)
        await verify(mock.fetch(.any)).didThrow(.error(TestError.self))
    }

    func testAsyncTypedThrows_DidThrowDefaultsToAnyFailure() async throws {
        let mock = MockTypedThrowingService()
        when(mock.fetch(.any)).thenThrow(.example)

        _ = try? await mock.fetch(1)

        await verify(mock.fetch(.any)).didThrow()
    }

    func testAsyncTypedThrows_DidThrowEquatableShorthand() async throws {
        let mock = MockTypedThrowingService()
        when(mock.fetch(.any)).thenThrow(.example)

        _ = try? await mock.fetch(1)

        await verify(mock.fetch(.any)).didThrow(.example)
        await verify(mock.fetch(.any)).didThrow(.example)
    }

    func testAsyncTypedThrows_DidThrowFailsWhenErrorDoesNotMatch() async throws {
        let mock = MockTypedThrowingService()
        when(mock.fetch(.any)).thenThrow(.example)

        _ = try? await mock.fetch(1)

        XCTExpectFailure("thrown .example does not match .other")
        await verify(mock.fetch(.any)).didThrow(.equal(.other))
    }
}

