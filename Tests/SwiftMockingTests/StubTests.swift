
import XCTest
@testable import SwiftMocking

final class StubTests: XCTestCase {

    func testReturnValue() {
        let stub = Stub<String, None, Int>(invocationMatcher: .init(matchers: .any))
        stub.thenReturn(42)
        let returnValue = try? stub.returnValue(for: .init(arguments: "test"))?.get()
        XCTAssertEqual(returnValue, 42)
    }

    func testReturnValueWithHandler() {
        let stub = Stub<String, None, Int>(invocationMatcher: .init(matchers: .any))
        stub.thenReturn { (input: String) in
            input.count
        }
        let returnValue = try? stub.returnValue(for: .init(arguments: "test"))?.get()
        XCTAssertEqual(returnValue, 4)
    }

    func testThenThrow() {
        let stub = Stub<String, Throws, Int>(invocationMatcher: .init(matchers: .any))
        stub.thenThrow(TestError.example)
        XCTAssertThrowsError(try stub.returnValue(for: .init(arguments: "test"))?.get()) {
            guard let error = $0 as? TestError else {
                return XCTFail("Wrong error type")
            }
            XCTAssertEqual(error, .example)
        }
    }

    func testPrecedence() {
        let stub1 = Stub<String, None, Int>(invocationMatcher: .init(matchers: .any))
        let stub2 = Stub<String, None, Int>(invocationMatcher: .init(matchers: .equal("test")))
        XCTAssertTrue(stub2.precedence > stub1.precedence)
    }
}
