
import XCTest
@testable import MockableTypes

final class MockTests: XCTestCase {
    func testSubscript_WhenSpyDoesNotExist_CreatesNewSpy() {
        let mock = Mock()
        let spy: Spy<Int, None, Void> = mock.myFunction
        XCTAssertNotNil(spy)
        XCTAssertEqual(mock.spies.count, 1)
    }

    func testSubscript_WhenSpyExists_ReturnsExistingSpy() {
        let mock = Mock()
        let spy1: Spy<Int, None, Void> = mock.myFunction
        let spy2: Spy<Int, None, Void> = mock.myFunction
        XCTAssertTrue(spy1 === spy2)
        XCTAssertEqual(mock.spies.count, 1)
    }

    func testSubscript_WithDifferentSignatures_CreatesDifferentSpies() {
        let mock = Mock()
        let _: Spy<Int, None, Void> = mock.myFunction
        let _: Spy<String, None, Void> = mock.myFunctionWithDifferentSignature
        XCTAssertEqual(mock.spies.count, 2)
    }
}
