import XCTest
@testable import SwiftMocking

final class ReturnTests: XCTestCase {

    func testSynchronousValue() throws {
        let subject = Return<None, Int>.value(42)
        let valueFromGet = subject.get()
        XCTAssertEqual(valueFromGet, 42)
    }

    func testThrowingValue() throws {
        let success = Return<Throws, String>.value("ok")
        let successValue = try success.get()
        XCTAssertEqual(successValue, "ok")

        let failure = Return<Throws, String>.error(TestError.example)
        XCTAssertThrowsError(try failure.get()) { error in
            XCTAssertTrue(error is TestError)
        }
    }

    func testAsyncValue() async {
        let subject = Return<Async, Int>.value(11)
        let asyncResult = await subject.get()
        XCTAssertEqual(asyncResult, 11)
    }

    func testAsyncThrowsValue() async throws {
        let success = Return<AsyncThrows, Double>.value(9.5)
        let successValue = try await success.get()
        XCTAssertEqual(successValue, 9.5)

        let failure = Return<AsyncThrows, Double>.error(TestError.example)
        var asyncThrowError: (any Error)?
        do {
            _ = try await failure.get()
        } catch {
            asyncThrowError = error
        }
        XCTAssertTrue(asyncThrowError is TestError)
    }

    func testAsyncInitializerUsesClosure() async {
        let expectation = XCTestExpectation(description: "async closure invoked")
        let subject = Return<Async, String>(asyncValue: {
            expectation.fulfill()
            return .success("value")
        })

        let result = await subject.get()
        XCTAssertEqual(result, "value")
        await fulfillment(of: [expectation], timeout: 1)
    }
}
