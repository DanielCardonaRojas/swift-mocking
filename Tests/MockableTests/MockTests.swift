
import XCTest
@testable import MockableTypes

final class MockTests: XCTestCase {
    func testSubscript_WhenSpyDoesNotExist_CreatesNewSpy() {
        let mock = Mock()
        let spy: Spy<Int, None, Void> = mock.myFunction
        XCTAssertNotNil(spy)
        XCTAssertEqual(mock.spies.count, 1)
    }

    func testSubscript_WhenSpyIsGeneric() {
        let mock = Mock()
        func createSpy<E: CustomStringConvertible>(type: E.Type, mock: Mock) -> Spy<E, None, String> {
            return mock.mySpy

        }
        let spy = createSpy(type: Int.self, mock: mock)
        let spy2 = createSpy(type: Int.self, mock: mock)

        XCTAssert(spy === spy2)
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

    func testClear_ClearsAllSpies() {
        let mock = Mock()
        let spy1: Spy<Int, None, Void> = mock.myFunction
        let spy2: Spy<String, None, Void> = mock.anotherFunction

        spy1.when(calledWith: 42).thenReturn(())
        spy1.call(42)

        spy2.when(calledWith: "test").thenReturn(())
        spy2.call("test")

        XCTAssertEqual(spy1.invocations.count, 1)
        XCTAssertEqual(spy2.invocations.count, 1)
        XCTAssertEqual(spy1.stubs.count, 1)
        XCTAssertEqual(spy2.stubs.count, 1)

        mock.clear()

        XCTAssertEqual(spy1.invocations.count, 0)
        XCTAssertEqual(spy2.invocations.count, 0)
        XCTAssertEqual(spy1.stubs.count, 0)
        XCTAssertEqual(spy2.stubs.count, 0)
    }
}
