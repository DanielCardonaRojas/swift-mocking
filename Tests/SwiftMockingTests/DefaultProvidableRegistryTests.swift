
import XCTest
import SwiftMocking

// Define some dummy types conforming to DefaultProvidable for testing
struct TestStruct: DefaultProvidable {
    static var defaultValue: TestStruct {
        return TestStruct(value: "default")
    }
    let value: String
}

class DefaultProvidableRegistryTests: XCTestCase {

    var registry: DefaultProvidableRegistry!

    override func setUp() {
        super.setUp()
        registry = DefaultProvidableRegistry.shared
        // Ensure a clean state for each test
        registry.deregister(TestStruct.self)
        registry.deregister(Int.self)
        registry.deregister(String.self)
    }

    func testRegisterAndIsRegistered() {
        XCTAssertFalse(registry.isRegistered(TestStruct.self))
        registry.register(TestStruct.self)
        XCTAssertTrue(registry.isRegistered(TestStruct.self))
    }

    func testDeregister() {
        registry.register(TestStruct.self)
        XCTAssertTrue(registry.isRegistered(TestStruct.self))
        registry.deregister(TestStruct.self)
        XCTAssertFalse(registry.isRegistered(TestStruct.self))
    }

    func testGetDefaultForRegisteredType() {
        registry.register(TestStruct.self)
        let defaultValue = registry.getDefaultForType(TestStruct.self)
        XCTAssertEqual(defaultValue?.value, "default")
    }

    func testGetDefaultForUnregisteredDefaultProvidableType() {
        // TestStruct conforms to DefaultProvidable but is not registered in this test
        let defaultValue = registry.getDefaultForType(TestStruct.self)
        XCTAssertNil(defaultValue)
    }

    func testGetDefaultForRegisteredBuiltInType() {
        registry.register(Int.self)
        let intDefaultValue = registry.getDefaultForType(Int.self)
        XCTAssertEqual(intDefaultValue, 0)

        registry.register(String.self)
        let stringDefaultValue = registry.getDefaultForType(String.self)
        XCTAssertEqual(stringDefaultValue, "")
    }

    func testGetDefaultForNonDefaultProvidableType() {
        // Attempt to get default for a type that does not conform to DefaultProvidable
        // This should always return nil as it cannot provide a default value
        class NonProvidableType {}
        let defaultValue = registry.getDefaultForType(NonProvidableType.self)
        XCTAssertNil(defaultValue)
    }
}
