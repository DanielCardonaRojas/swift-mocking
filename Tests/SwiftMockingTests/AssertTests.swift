
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
}
