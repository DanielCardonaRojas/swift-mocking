
import XCTest
@testable import SwiftMocking

final class SpyTests: XCTestCase {

    // MARK: - Basic Stubbing and Invocation Recording

    func test_spy_recordsInvocations_andReturnsStubbedValue() {
        let spy = Spy<String, None, Int>()
        spy.when(calledWith:.any).thenReturn(10)

        XCTAssertEqual(spy.call("hello"), 10)
        XCTAssertEqual(spy.call("world"), 10)


        XCTAssertEqual(spy.invocations.count, 2)
        XCTAssertEqual(spy.invocations[0].arguments, "hello")
        XCTAssertEqual(spy.invocations[1].arguments, "world")
    }

    func test_spy_recordsInvocations_verify_counts() {
        let spy = Spy<String, None, Int>()
        spy.when(calledWith:.any).thenReturn(10)
        spy.call( "hello" )
        spy.call( "hello" )
        XCTAssert(spy.verify(calledWith: .equal("hello"), count: .equal(2)))
    }

    func test_can_overwrite_stub() {
        let spy = Spy<String, None, Int>()
        spy.when(calledWith:"hello").thenReturn(10)
        spy.when(calledWith:"hello").thenReturn(13)
        let result = spy.call( "hello" )
        XCTAssertEqual(result, 13)
    }

    func testAnyPrecedence() {
        let spy = Spy<String, None, Int>()
        spy.when(calledWith: .any).thenReturn(10)
        spy.when(calledWith: "hello").thenReturn(13)
        spy.when(calledWith: .any).thenReturn(7)

        // Ensure matcher .any has lower priority
        let result = spy.call( "hello" )
        XCTAssertEqual(result, 13)
    }

    func testEqualMatcherHasHigherPrecedenceThanPredicate() {
        let spy = Spy<String, None, Int>()
        // Order of these does not matter since they have different precedence values
        spy.when(calledWith: .any).thenReturn(7)
        spy.when(calledWith: "hello").thenReturn(13)
        spy.when(calledWith: .any(that: { $0.count > 8 })).thenReturn(17)

        // Ensure matcher .any has lower priority
        XCTAssertEqual(spy.call("hello"), 13) // should be matched by .equal matcher
        XCTAssertEqual(spy.call("long_input"), 17) // should be matched by predicate matcher
        XCTAssertEqual(spy.call("short"), 7) // Should be matched by any matcher
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
        spy.defaultProviderRegistry = .default
        spy.call("action1")
        spy.call("action2")

        XCTAssertEqual(spy.invocations.count, 2)
        XCTAssertEqual(spy.invocations[0].arguments, "action1")
        XCTAssertEqual(spy.invocations[1].arguments, "action2")
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

    func test_spy_verifyInOrder() {
        let spy = Spy<String, None, Int>()

        spy.when(calledWith:.any).thenReturn(1)
        spy.call("apple")
        spy.call("lemon")
        spy.call("banana")

        XCTAssert(spy.verifyInOrder([
            InvocationMatcher(matchers: "apple"),
            InvocationMatcher(matchers: "banana")
        ]))

        XCTAssertFalse(spy.verifyInOrder([
            InvocationMatcher(matchers: "banana"),
            InvocationMatcher(matchers: "apple")
        ]))
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

    func test_spy_async_recordsInvocations_andReturnsStubbedValue() async {
        let spy = Spy<String, Async, Int>()
        spy.when(calledWith: .any).thenReturn(10)

        let result1 = await spy.call("hello")
        let result2 = await spy.call("world")

        XCTAssertEqual(result1, 10)
        XCTAssertEqual(result2, 10)

        XCTAssertEqual(spy.invocations.count, 2)
        XCTAssertEqual(spy.invocations[0].arguments, "hello")
        XCTAssertEqual(spy.invocations[1].arguments, "world")
    }

    func test_spy_asyncThrows_recordsInvocations_andReturnsStubbedValue() async throws {
        let spy = Spy<String, AsyncThrows, Int>()
        spy.when(calledWith: .any).thenReturn(10)

        let result1 = try await spy.call("hello")
        let result2 = try await spy.call("world")

        XCTAssertEqual(result1, 10)
        XCTAssertEqual(result2, 10)

        XCTAssertEqual(spy.invocations.count, 2)
        XCTAssertEqual(spy.invocations[0].arguments, "hello")
        XCTAssertEqual(spy.invocations[1].arguments, "world")
    }

    func test_spy_asyncThrows_verification() async {
        let spy = Spy<String, AsyncThrows, Int>()
        spy.when(calledWith: .any).thenThrow(TestError.example)
        do {
            _ = try await spy.call("something")
        } catch {

        }
        let didThrow = await spy.verifyThrows(.error(TestError.self))
        XCTAssert(didThrow)
    }

    func test_spy_async_canUseAsyncReturnClosure() async throws {
        let spy = Spy<String, AsyncThrows, Int>()
        spy.when(calledWith: .any).thenReturn { value in
            try await Task.sleep(for: .milliseconds(20))
            return value.count
        }

        let result = try await spy.call("hello")
        verify(spy(.any)).captured({ string in
            XCTAssertEqual("hello", string)
        })
        XCTAssertEqual(result, 5)
    }

    func test_asyncThrows_serviceInvokedInsideTask_eventuallyExecutes() async throws {
        let spy = Spy<String, AsyncThrows, Void>()
        spy.when(calledWith: .equal("ping")).thenReturn { _ in
            try await Task.sleep(for: .milliseconds(10))
        }

        let sut = FireAndForgetController(service: spy.asFunction())
        sut.load("ping")
        verifyNever(spy(.any)) // Has not called spy at this point

        try await until(spy(.equal("ping")))

        verify(spy("ping")).called()
    }

    func test_callback() async {
        // represents something like: fetch(url: String, completion: @escaping (Int) -> Void)
        let spy = Spy<String, (Int) -> Void, None, Void>()
        let expectation = XCTestExpectation()

        spy.when(calledWith: .any, .any).then { url, completion in
            completion(7)
        }

        spy.call("", { num in
            if num == 7 {
                expectation.fulfill()
            }
        })

        await fulfillment(of: [expectation], timeout: 1)
    }

    func test_spy_invoke_race_condition() {
        let spy = Spy<Int, None, Void>()
        spy.when(calledWith: .any).thenReturn(Void())
        let queue = DispatchQueue(label: "com.swiftmocking.race_condition_test", attributes: .concurrent)
        let group = DispatchGroup()
        let iterationCount = 100

        for i in 0..<iterationCount {
            group.enter()
            queue.async {
                spy.call(i)
                group.leave()
            }
        }

        group.wait()

        XCTAssertEqual(spy.invocations.count, iterationCount)
    }

    func test_spy_stub_race_condition() {
        let spy = Spy<Int, None, Void>()
        let queue = DispatchQueue(label: "com.swiftmocking.stub_race_condition_test", attributes: .concurrent)
        let group = DispatchGroup()
        let iterationCount = 100

        for i in 0..<iterationCount {
            group.enter()
            queue.async {
                spy.when(calledWith: .equal(i)).thenReturn(Void())
                group.leave()
            }
        }

        group.wait()

        XCTAssertEqual(spy.stubs.count, iterationCount)
    }

    func test_spy_with_results_param() {
        let spy = Spy<Result<String, any Error>, None, Int>()
        when(spy(.failure(.is(AnotherError.self)))).thenReturn(4)
        when(spy(.failure(.any))).thenReturn(3)
        when(spy(.success(.any))).thenReturn(-1)
        when(spy(.success(.equal("3")))).thenReturn(7)

        XCTAssertEqual(spy.call(.failure(TestError.example)), 3)
        XCTAssertEqual(spy.call(.failure(AnotherError())), 4)
        XCTAssertEqual(spy.call(.success("3")), 7)
        XCTAssertEqual(spy.call(.success("hello")), -1)

        let spy2 = Spy<Result<String, TestError>, None, Int>()
        when(spy2(.failure(.equal(.example)))).thenReturn(9)
        when(spy2(.failure(.any))).thenReturn(2)
        when(spy2(.success(.any))).thenReturn(-1)
        when(spy2(.success(.equal("3")))).thenReturn(7)

        XCTAssertEqual(spy2.call(.failure(TestError.example)), 9)
        XCTAssertEqual(spy2.call(.failure(TestError.other)), 2)
        XCTAssertEqual(spy2.call(.success("3")), 7)
        XCTAssertEqual(spy2.call(.success("hello")), -1)
    }
}

private struct FireAndForgetController {
    let service: (String) async throws -> Void

    func load(_ value: String) {
        Task {
            try? await Task.sleep(for: .milliseconds(50))
            _ = try? await service(value)
        }
    }
}
