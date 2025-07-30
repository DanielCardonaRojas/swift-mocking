
import XCTest
@testable import SwiftMocking

final class ArgMatcherTests: XCTestCase {

    func testAnyMatcher() {
        let matcher: ArgMatcher<Int> = .any
        XCTAssertTrue(matcher(5))
        XCTAssertTrue(matcher(0))
    }

    func testAnyThatMatcher() {
        let matcher: ArgMatcher<Int> = .any(that: { $0 > 5 })
        XCTAssertTrue(matcher(6))
        XCTAssertFalse(matcher(5))
    }

    func testAsMatcher() {
        let matcher: ArgMatcher<Any> = .as(String.self)
        XCTAssertTrue(matcher("test"))
        XCTAssertFalse(matcher(5))
    }

    func testVariadicMatcher() {
        let matcher: ArgMatcher<[Int]> = .variadic(.equal(1), .equal(2))
        XCTAssertTrue(matcher([1, 2]))
        XCTAssertFalse(matcher([1, 3]))
    }

    func testEqualMatcher() {
        let matcher: ArgMatcher<Int> = .equal(5)
        XCTAssertTrue(matcher(5))
        XCTAssertFalse(matcher(6))
    }

    func testLessThanMatcher() {
        let matcher: ArgMatcher<Int> = .lessThan(5)
        XCTAssertTrue(matcher(4))
        XCTAssertFalse(matcher(5))
    }

    func testGreaterThanMatcher() {
        let matcher: ArgMatcher<Int> = .greaterThan(5)
        XCTAssertTrue(matcher(6))
        XCTAssertFalse(matcher(5))
    }

    func testIdenticalToMatcher() {
        class TestObject {}
        let object = TestObject()
        let matcher: ArgMatcher<TestObject> = .identical(object)
        XCTAssertTrue(matcher(object))
        XCTAssertFalse(matcher(TestObject()))
    }

    func testNotNilMatcher() {
        let matcher: ArgMatcher<Int?> = .notNil()
        XCTAssertTrue(matcher(5))
        XCTAssertFalse(matcher(nil))
    }

    func testNilMatcher() {
        let matcher: ArgMatcher<Int?> = .nil()
        XCTAssertTrue(matcher(nil))
        XCTAssertFalse(matcher(5))
    }

    func testAnyErrorMatcher() {
        let matcher: ArgMatcher<Error> = .anyError()
        XCTAssertTrue(matcher(TestError.example))
    }

    func testErrorMatcher() {
        let matcher: ArgMatcher<Error> = .error(TestError.self)
        XCTAssertTrue(matcher(TestError.example))
        XCTAssertFalse(matcher(AnotherError()))
    }

    func testAnyWhereMatcher() {
        struct User {
            let id: String
        }
        let matcher: ArgMatcher<User> = .any(where: \.id, "123")
        XCTAssertTrue(matcher(User(id: "123")))
        XCTAssertFalse(matcher(User(id: "456")))
    }

    func testExpressibleByIntegerLiteral() {
        let matcher: ArgMatcher<Int> = 5
        XCTAssertTrue(matcher(5))
        XCTAssertFalse(matcher(6))
    }

    func testExpressibleByFloatLiteral() {
        let matcher: ArgMatcher<Double> = 5.0
        XCTAssertTrue(matcher(5.0))
        XCTAssertFalse(matcher(6.0))
    }

    func testExpressibleByBooleanLiteral() {
        let matcher: ArgMatcher<Bool> = true
        XCTAssertTrue(matcher(true))
        XCTAssertFalse(matcher(false))
    }

    func testExpressibleByStringLiteral() {
        let matcher: ArgMatcher<String> = "test"
        XCTAssertTrue(matcher("test"))
        XCTAssertFalse(matcher("other"))
    }
}
