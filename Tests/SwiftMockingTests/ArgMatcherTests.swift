
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

    // MARK: - Numeric Matchers

    func testBetweenMatcher() {
        let matcher: ArgMatcher<Int> = .between(10, 20)
        XCTAssertTrue(matcher(10))
        XCTAssertTrue(matcher(15))
        XCTAssertTrue(matcher(20))
        XCTAssertFalse(matcher(9))
        XCTAssertFalse(matcher(21))
    }

    func testApproximatelyMatcher() {
        let matcher: ArgMatcher<Double> = .approximately(3.14159, tolerance: 0.001)
        XCTAssertTrue(matcher(3.14159))
        XCTAssertTrue(matcher(3.1416))
        XCTAssertTrue(matcher(3.1415))
        XCTAssertFalse(matcher(3.143))
        XCTAssertFalse(matcher(3.139))
    }

    func testApproximatelyMatcherWithDefaultTolerance() {
        let matcher: ArgMatcher<Float> = .approximately(2.5, tolerance: 0.001)
        XCTAssertTrue(matcher(2.5))
        XCTAssertTrue(matcher(2.5005))
        XCTAssertTrue(matcher(2.4995))
        XCTAssertFalse(matcher(2.502))
        XCTAssertFalse(matcher(2.498))
    }

    // MARK: - String Matchers

    func testStringContainsMatcher() {
        let matcher: ArgMatcher<String> = .contains("test")
        XCTAssertTrue(matcher("testing"))
        XCTAssertTrue(matcher("test"))
        XCTAssertTrue(matcher("pretest"))
        XCTAssertFalse(matcher("example"))
        XCTAssertFalse(matcher(""))
    }

    func testStringStartsWithMatcher() {
        let matcher: ArgMatcher<String> = .startsWith("http")
        XCTAssertTrue(matcher("https://example.com"))
        XCTAssertTrue(matcher("http://test.com"))
        XCTAssertTrue(matcher("http"))
        XCTAssertFalse(matcher("ftp://example.com"))
        XCTAssertFalse(matcher(""))
    }

    func testStringEndsWithMatcher() {
        let matcher: ArgMatcher<String> = .endsWith(".json")
        XCTAssertTrue(matcher("data.json"))
        XCTAssertTrue(matcher("config.json"))
        XCTAssertTrue(matcher(".json"))
        XCTAssertFalse(matcher("data.xml"))
        XCTAssertFalse(matcher("json"))
    }

    func testStringMatchesRegexMatcher() {
        let emailMatcher: ArgMatcher<String> = .matches(#"^[\w\.-]+@[\w\.-]+\.\w+$"#)
        XCTAssertTrue(emailMatcher("test@example.com"))
        XCTAssertTrue(emailMatcher("user.name@domain.org"))
        XCTAssertFalse(emailMatcher("invalid-email"))
        XCTAssertFalse(emailMatcher("test@"))

        let phoneNumberMatcher: ArgMatcher<String> = .matches(#"\d{3}-\d{3}-\d{4}"#)
        XCTAssertTrue(phoneNumberMatcher("123-456-7890"))
        XCTAssertFalse(phoneNumberMatcher("123-45-6789"))
        XCTAssertFalse(phoneNumberMatcher("not-a-phone"))
    }

    func testStringMatchesInvalidRegex() {
        let matcher: ArgMatcher<String> = .matches("[invalid")
        XCTAssertFalse(matcher("any string"))
    }

    // MARK: - Collection Matchers

    func testCollectionIsEmptyMatcher() {
        let matcher: ArgMatcher<[Int]> = .isEmpty()
        XCTAssertTrue(matcher([]))
        XCTAssertFalse(matcher([1]))
        XCTAssertFalse(matcher([1, 2, 3]))
    }

    func testCollectionHasCountMatcher() {
        let matcher: ArgMatcher<[String]> = .hasCount(3)
        XCTAssertTrue(matcher(["a", "b", "c"]))
        XCTAssertFalse(matcher([]))
        XCTAssertFalse(matcher(["a"]))
        XCTAssertFalse(matcher(["a", "b", "c", "d"]))
    }

    func testCollectionHasCountBetweenMatcher() {
        let matcher: ArgMatcher<[Int]> = .hasCountBetween(2, 4)
        XCTAssertTrue(matcher([1, 2]))
        XCTAssertTrue(matcher([1, 2, 3]))
        XCTAssertTrue(matcher([1, 2, 3, 4]))
        XCTAssertFalse(matcher([1]))
        XCTAssertFalse(matcher([1, 2, 3, 4, 5]))
        XCTAssertFalse(matcher([]))
    }

    func testCollectionContainsMatcher() {
        let matcher: ArgMatcher<[String]> = .contains("test")
        XCTAssertTrue(matcher(["test"]))
        XCTAssertTrue(matcher(["one", "test", "three"]))
        XCTAssertTrue(matcher(["test", "other"]))
        XCTAssertFalse(matcher([]))
        XCTAssertFalse(matcher(["one", "two"]))
        XCTAssertFalse(matcher(["testing"]))
    }

    func testCollectionContainsWithSetMatcher() {
        let matcher: ArgMatcher<Set<Int>> = .contains(42)
        XCTAssertTrue(matcher(Set([42])))
        XCTAssertTrue(matcher(Set([1, 42, 3])))
        XCTAssertFalse(matcher(Set([])))
        XCTAssertFalse(matcher(Set([1, 2, 3])))
    }
}
