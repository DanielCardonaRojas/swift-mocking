//
//  StubbingBuilderTests.swift
//  swift-mocking
//
//  Created by Daniel Cardona
//

import XCTest
@testable import SwiftMocking

class StubbingBuilderTests: MockingTestCase {

    func test_whenAll_configuresMultipleStubs() {
        let spy1 = Spy<String, None, Int>(label: "spy1.method")
        let spy2 = Spy<Int, None, String>(label: "spy2.method")
        let spy3 = Spy<Bool, None, Double>(label: "spy3.method")

        // Arrange using whenAll - no nested when() calls!
        when {
            spy1(.any).thenReturn(42)
            spy2(.any).thenReturn("result")
            spy3(.any).thenReturn(3.14)
        }

        // Act & Assert
        let result1 = spy1("test")
        let result2 = spy2(10)
        let result3 = spy3(true)

        XCTAssertEqual(result1, 42)
        XCTAssertEqual(result2, "result")
        XCTAssertEqual(result3, 3.14)
    }

    func test_whenAll_withThrowingStubs() {
        let spy = Spy<String, Throws, Int>(label: "throwingSpy.method")

        struct TestError: Error, Equatable {}

        when {
            spy(.equal("success")).thenReturn(100)
            spy(.equal("fail")).thenThrow(TestError())
        }

        // Test successful case
        let successResult = try? spy("success")
        XCTAssertEqual(successResult, 100)

        // Test error case
        XCTAssertThrowsError(try spy("fail")) { error in
            XCTAssertTrue(error is TestError)
        }
    }

    func test_whenAll_withAsyncStubs() async {
        let spy = Spy<String, Async, Int>(label: "asyncSpy.method")

        when {
            spy(.equal("async1")).thenReturn(1)
            spy(.equal("async2")).thenReturn(2)
        }

        let result1 = await spy("async1")
        let result2 = await spy("async2")

        XCTAssertEqual(result1, 1)
        XCTAssertEqual(result2, 2)
    }

    func test_whenAll_withAsyncThrowingStubs() async throws {
        let spy = Spy<String, AsyncThrows, Int>(label: "asyncThrowingSpy.method")

        struct AsyncError: Error {}

        when {
            spy(.equal("success")).thenReturn(99)
            spy(.equal("fail")).thenThrow(AsyncError())
        }

        let result = try await spy("success")
        XCTAssertEqual(result, 99)

        do {
            _ = try await spy("fail")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is AsyncError)
        }
    }

    func test_whenAll_withHandlers() {
        let spy = Spy<Int, None, String>(label: "handlerSpy.method")

        when {
            spy(.any).thenReturn { input in
                "Value: \(input)"
            }
        }

        let result = spy(42)
        XCTAssertEqual(result, "Value: 42")
    }

    func test_whenAll_withOptionalConfiguration() {
        let spy = Spy<String, None, Int>(label: "optionalSpy.method")
        let shouldStub = true

        when {
            spy(.equal("always")).thenReturn(1)

            if shouldStub {
                spy(.equal("conditional")).thenReturn(2)
            }
        }

        XCTAssertEqual(spy("always"), 1)
        XCTAssertEqual(spy("conditional"), 2)
    }

    func test_whenAll_withConditionalLogic() {
        let spy = Spy<String, None, Int>(label: "conditionalSpy.method")
        let useHighValue = true

        when {
            if useHighValue {
                spy(.any).thenReturn(1000)
            } else {
                spy(.any).thenReturn(10)
            }
        }

        XCTAssertEqual(spy("anything"), 1000)
    }

    func test_whenAll_preservesStubPrecedence() {
        let spy = Spy<String, None, Int>(label: "precedenceSpy.method")

        when {
            spy(.any).thenReturn(1)
            spy(.equal("specific")).thenReturn(2)
        }

        // More specific stub should take precedence
        XCTAssertEqual(spy("specific"), 2)
        XCTAssertEqual(spy("other"), 1)
    }

    func test_whenAll_emptyBlock() {
        // Should not crash with empty block
        when {
        }
    }

    func test_whenAll_mixedEffectTypes() {
        let syncSpy = Spy<String, None, Int>(label: "syncSpy")
        let throwingSpy = Spy<String, Throws, Int>(label: "throwingSpy")

        struct TestError: Error {}

        when {
            syncSpy(.any).thenReturn(1)
            throwingSpy(.equal("success")).thenReturn(2)
            throwingSpy(.equal("fail")).thenThrow(TestError())
        }

        XCTAssertEqual(syncSpy("test"), 1)
        XCTAssertEqual(try? throwingSpy("success"), 2)
        XCTAssertThrowsError(try throwingSpy("fail"))
    }

    func test_backwardCompatibility_whenReturnsDiscardable() {
        let spy = Spy<String, None, Int>(label: "compatSpy.method")

        // Old style should still work (no error about unused result)
        when(spy(.any)).thenReturn(42)

        XCTAssertEqual(spy("test"), 42)
    }
}
