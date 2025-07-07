
import XCTest
@testable import Mockable

final class SpyTests: XCTestCase {

    // MARK: - Basic Stubbing and Invocation Recording

    func test_spy_recordsInvocations_andReturnsStubbedValue() {
        let spy = Spy<String, None, Int>()
        spy.when(calledWith:.any).thenReturn(10)

        XCTAssertEqual(spy.call("hello"), 10)
        XCTAssertEqual(spy.call("world"), 10)


        XCTAssertEqual(spy.invocations.count, 2)
        XCTAssertEqual(spy.invocations[0], "hello")
        XCTAssertEqual(spy.invocations[1], "world")
    }

    func test_spy_recordsInvocations_verify_counts() {
        let spy = Spy<String, None, Int>()
        spy.when(calledWith:.any).thenReturn(10)
        spy.call( "hello" )
        spy.call( "hello" )
        XCTAssert(spy.verify(calledWith: .equal("hello"), count: .equal(2)))
    }

    func test_spy_withVoidInput_recordsInvocations_andReturnsStubbedValue() {
        let spy = Spy<Void, None, String>()
        spy.when(calledWith:.any).thenReturn("success")

        XCTAssertEqual(spy.call(()), "success")
        XCTAssertEqual(spy.call(()), "success")

        XCTAssertEqual(spy.invocations.count, 2)
    }

    func test_spy_withVoidOutput_recordsInvocations() {
        let spy = Spy<String, None, Void>()
        spy.when(calledWith:.any).thenReturn(())

        spy.call("action1")
        spy.call("action2")

        XCTAssertEqual(spy.invocations.count, 2)
        XCTAssertEqual(spy.invocations[0], "action1")
        XCTAssertEqual(spy.invocations[1], "action2")
    }

//    // MARK: - Conditional Stubbing

    func test_spy_conditionalStubbing_matchesCorrectly() {
        let spy = Spy<String, None, Int>()

        spy.when(calledWith:.equal("apple")).thenReturn(1)
        spy.when(calledWith:.any).thenReturn(7)

        XCTAssertEqual(spy.call("apple"), 1, "Should match 'apple' specific stub")
        XCTAssertEqual(spy.call("unknown"), 7, "Should match any other specific stub")
        XCTAssert(spy.verifyCalled(.equal(2)))
    }

    func test_spy_any() {
        let spy = Spy<String, None, Int>()
        spy.when(calledWith:.equal("Hola")).thenReturn(2)
        spy.when(calledWith:.equal("Hello")).thenReturn(3)
        spy.when(calledWith:.any).thenReturn(7)

        XCTAssertEqual(spy.call("Hola"), 2, "Should match any other specific stub")
        XCTAssertEqual(spy.call("Hello"), 3, "Should match any other specific stub")
        XCTAssertEqual(spy.call("unknown"), 7, "Should match any other specific stub")
    }

    func test_spy_conditionalStubbing_withMultipleArguments() {
        let spy = Spy<String, Int, None, String>()
        spy.when(calledWith:.equal("itemA"), .lessThan(15)).thenReturn("A10")
        spy.when(calledWith:.equal("itemB"), .equal(23)).thenReturn("B23")
        XCTAssertEqual(spy.call("itemA", 10), "A10", "Should match itemA and 10")
        XCTAssertEqual(spy.call("itemB", 23), "B23", "Should match itemB and 23")
        XCTAssertEqual(spy.invocations.count, 2)
    }

    func test_spy_throwing_verification() throws {
        let spy = Spy<String, Throws, Int>()
        spy.when(calledWith: .any).thenThrow(TestError.example)
        do {
            try spy.call("something")
        } catch {

        }
        XCTAssert(spy.verifyThrows(.error(TestError.self)))
    }
}
