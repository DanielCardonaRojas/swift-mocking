
import XCTest
@testable import SwiftMocking

final class AssertTests: XCTestCase {

    var spy: Spy<String, None, Void>!

    override func setUp() {
        super.setUp()
        spy = Spy()
        spy.when(calledWith: .any).thenReturn(())
    }

    func testAssertCalled() throws {
        spy.call("test")
        let assert = Assert(spy: spy)
        try assert.assert(nil)
    }

    func testAssertCalledWithMatcher() throws {
        spy.call("test")
        let assert = Assert(invocationMatcher: .init(matchers: .equal("test")), spy: spy)
        try assert.assert(nil)
    }

    func testAssertCalledFailsWhenNoInvocations() {
        let assert = Assert(spy: spy)
        XCTAssertThrowsError(try assert.assert(nil)) {
            guard let error = $0 as? MockingError else {
                return XCTFail("Wrong error type")
            }
            XCTAssertEqual(error, .unfulfilledCallCount(0))
        }
    }

    func testAssertCalledFailsWhenNoMatchingInvocations() {
        spy.call("other")
        let assert = Assert(invocationMatcher: .init(matchers: .equal("test")), spy: spy)
        XCTAssertThrowsError(try assert.assert(nil)) {
            guard let error = $0 as? MockingError else {
                return XCTFail("Wrong error type")
            }
            XCTAssertEqual(error, .unfulfilledCallCount(0))
        }
    }

    func testDoesThrow() throws {
        let throwingSpy = Spy<String, Throws, Void>()
        throwingSpy.when(calledWith: .any).thenThrow(TestError.example)
        _ = try? throwingSpy.call("test")

        let assert = Assert(spy: throwingSpy)
        try assert.doesThrow()
    }

    func testDoesThrowFailsWhenNoErrorThrown() {
        let throwingSpy = Spy<String, Throws, Void>()
        throwingSpy.when(calledWith: .any).thenReturn(())
        _ = try? throwingSpy.call("test")

        let assert = Assert(spy: throwingSpy)
        XCTAssertThrowsError(try assert.doesThrow()) {
            guard let error = $0 as? MockingError else {
                return XCTFail("Wrong error type")
            }
            XCTAssertEqual(error, .didNotThrow)
        }
    }

    func testDoesThrowWithMatcher() throws {
        let throwingSpy = Spy<String, Throws, Void>()
        throwingSpy.when(calledWith: .any).thenThrow(TestError.example)
        _ = try? throwingSpy.call("test")

        let assert = Assert(spy: throwingSpy)
        try assert.doesThrow(.error(TestError.self))
    }

    func testDoesThrowWithMatcherFailsWhenWrongError() {
        let throwingSpy = Spy<String, Throws, Void>()
        throwingSpy.when(calledWith: .any).thenThrow(AnotherError())
        _ = try? throwingSpy.call("test")

        let assert = Assert(spy: throwingSpy)
        XCTAssertThrowsError(try assert.doesThrow(.error(TestError.self))) {
            guard let error = $0 as? MockingError else {
                return XCTFail("Wrong error type")
            }
            XCTAssertEqual(error, .didNotMatchThrown([AnotherError()]))
        }
    }

    func testNeverCalledSucceedsWhenMethodNotCalled() {
        let assert = Assert(spy: spy)
        assert.neverCalled()
    }

    func testNeverCalledWithSpecificMatcherSucceedsWhenDifferentArgumentCalled() {
        spy.call("different")
        let assert = Assert(invocationMatcher: .init(matchers: .equal("test")), spy: spy)
        assert.neverCalled()
    }

    func testNeverCalledIsEquivalentToCalledZero() throws {
        let assert1 = Assert(spy: spy)
        let assert2 = Assert(spy: spy)

        XCTAssertNoThrow(try assert1.assert(.equal(0)))

        assert2.neverCalled()
    }

    func testAsyncThrowsAssertion() async throws {
        let asyncSpy = Spy<String, AsyncThrows, Void>()
        when(asyncSpy(.any)).thenThrow(TestError.example)

        _ = try? await asyncSpy.call("value")

        await verify(asyncSpy(.any)).throws()
    }
    
    // MARK: - verifyZeroInteractions Tests
    
    func testVerifyZeroInteractionsSucceedsWhenMockUnused() {
        let mock = TestMock()
        
        // Should not throw - mock has no interactions
        verifyZeroInteractions(mock)
    }
    
    func testVerifyZeroInteractionsWithMultipleSpies() {
        let mock = TestMock()
        
        // Access multiple spies but don't call them
        _ = mock.testMethod
        _ = mock.anotherMethod
        _ = mock.thirdMethod
        
        // Should succeed - spies exist but have no invocations
        verifyZeroInteractions(mock)
    }
    
    func testVerifyZeroInteractionsCountsCorrectly() {
        let mock = TestMock()
        
        // Make some method calls to record invocations
        mock.testMethod.call("test1")
        mock.testMethod.call("test2")
        mock.anotherMethod.call(42)
        
        // Verify total invocation count is correct
        let totalInvocations = mock.spies.values.flatMap { $0 }.reduce(0) { $0 + $1.invocationCount }
        XCTAssertEqual(totalInvocations, 3)
    }
    
    // MARK: - captured() Tests
    
    func testCapturedBasicFunctionality() throws {
        spy.call("hello")
        spy.call("world")
        
        var capturedArguments: [String] = []
        let assert = Assert(spy: spy)
        
        try assert.captures { argument in
            capturedArguments.append(argument)
        }
        
        XCTAssertEqual(capturedArguments, ["hello", "world"])
    }
    
    func testCapturedWithMatcher() throws {
        spy.call("hello")
        spy.call("world")
        spy.call("test")
        
        var capturedArguments: [String] = []
        let assert = Assert(invocationMatcher: .init(matchers: .startsWith("t")), spy: spy)
        
        try assert.captures { argument in
            capturedArguments.append(argument)
        }
        
        XCTAssertEqual(capturedArguments, ["test"])
    }
    
    func testCapturedWithMultipleArguments() throws {
        let multiArgSpy = Spy<String, Int, None, Void>()
        multiArgSpy.when(calledWith: .any, .any).thenReturn(())
        
        multiArgSpy.call("first", 1)
        multiArgSpy.call("second", 2)
        
        var capturedPairs: [(String, Int)] = []
        let assert = Assert(spy: multiArgSpy)
        
        try assert.captures { string, int in
            capturedPairs.append((string, int))
        }
        
        XCTAssertEqual(capturedPairs.count, 2)
        XCTAssertEqual(capturedPairs[0].0, "first")
        XCTAssertEqual(capturedPairs[0].1, 1)
        XCTAssertEqual(capturedPairs[1].0, "second")
        XCTAssertEqual(capturedPairs[1].1, 2)
    }
    
    func testCapturedThrowsWhenNoMatchingInvocations() {
        let assert = Assert(spy: spy)
        
        XCTAssertThrowsError(try assert.captures { _ in }) { error in
            guard let mockingError = error as? MockingError else {
                return XCTFail("Wrong error type")
            }
            XCTAssertEqual(mockingError, .noMatchingInvocations)
        }
    }
    
    func testCapturedThrowsWhenNoMatchingInvocationsWithMatcher() {
        spy.call("hello")
        let assert = Assert(invocationMatcher: .init(matchers: .equal("world")), spy: spy)
        
        XCTAssertThrowsError(try assert.captures { _ in }) { error in
            guard let mockingError = error as? MockingError else {
                return XCTFail("Wrong error type")
            }
            XCTAssertEqual(mockingError, .noMatchingInvocations)
        }
    }
    
    func testCapturedInspectorCanThrow() {
        spy.call("test")
        let assert = Assert(spy: spy)
        
        // Test core captures() method that propagates inspector errors
        XCTAssertThrowsError(try assert.captures { argument in
            if argument == "test" {
                throw TestError.example
            }
        }) { error in
            XCTAssertTrue(error is TestError)
        }
    }
    
    func testCapturedAfterCallVerification() {
        spy.call("test")
        spy.call("hello")
        
        var capturedArguments: [String] = []
        let assert = Assert(spy: spy)
        
        // Test the logical flow: verify call count first, then inspect arguments
        assert.called(.equal(2))
        assert.captured { argument in
            capturedArguments.append(argument)
        }
        
        XCTAssertEqual(capturedArguments, ["test", "hello"])
    }
    
    func testCapturedWithTestSupportExtension() {
        spy.call("hello")
        spy.call("world")
        
        var capturedArguments: [String] = []
        let assert = Assert(spy: spy)
        
        // Test the TestSupport extension that handles errors automatically (no return value)
        assert.captured { argument in
            capturedArguments.append(argument)
        }
        
        XCTAssertEqual(capturedArguments, ["hello", "world"])
    }
}

// MARK: - Test Mock for verifyZeroInteractions

@dynamicMemberLookup
class TestMock: Mock {
    var testMethod: Spy<String, None, Void> {
        self[dynamicMember: "testMethod"]
    }
    
    var anotherMethod: Spy<Int, None, String> {
        self[dynamicMember: "anotherMethod"]
    }
    
    var thirdMethod: Spy<Double, None, Bool> {
        self[dynamicMember: "thirdMethod"]
    }
}
