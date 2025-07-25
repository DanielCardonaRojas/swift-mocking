
import XCTest
import SwiftMocking

// Define some dummy types conforming to DefaultProvidable for testing
class DefaultProvidableRegistryTests: XCTestCase {

    var registry: DefaultProvidableRegistry!

    override func setUp() {
        super.setUp()
        registry = DefaultProvidableRegistry.shared
    }

    func testDeregister() {
        registry.deregister(.void())
        XCTAssertNil(registry.getDefaultForType(Void.self))
    }

    func testVoid() {
        XCTAssertNotNil(registry.getDefaultForType(Void.self))
    }

    func testArray() {
        XCTAssertNotNil(registry.getDefaultForType([Int].self))
        XCTAssertNotNil(registry.getDefaultForType([String].self))
        XCTAssertNotNil(registry.getDefaultForType([Bool].self))
        XCTAssertNotNil(registry.getDefaultForType([Double].self))
        XCTAssertNotNil(registry.getDefaultForType([Optional<Int>].self))
    }

    func testSet() {
        XCTAssertNotNil(registry.getDefaultForType(Set<Int>.self))
        XCTAssertNotNil(registry.getDefaultForType(Set<String>.self))
        XCTAssertNotNil(registry.getDefaultForType(Set<Bool>.self))
        XCTAssertNotNil(registry.getDefaultForType(Set<Double>.self))
    }

    func testDictionary() {
        XCTAssertNotNil(registry.getDefaultForType(Dictionary<String, Int>.self))
        XCTAssertNotNil(registry.getDefaultForType(Dictionary<String, String>.self))
        XCTAssertNotNil(registry.getDefaultForType(Dictionary<String, Bool>.self))
        XCTAssertNotNil(registry.getDefaultForType(Dictionary<String, Double>.self))
    }

    func testOptional() {
        XCTAssertEqual(registry.getDefaultForType(Optional<Int>.self), .some(nil))
        XCTAssertEqual(registry.getDefaultForType(Optional<String>.self), .some(nil))
        XCTAssertEqual(registry.getDefaultForType(Optional<Bool>.self), .some(nil))
        XCTAssertEqual(registry.getDefaultForType(Optional<Double>.self), .some(nil))
    }

    func testNumeric() {
        XCTAssertNotNil(registry.getDefaultForType(Int.self))
        XCTAssertNotNil(registry.getDefaultForType(Double.self))
        XCTAssertNotNil(registry.getDefaultForType(Float.self))
    }

}
