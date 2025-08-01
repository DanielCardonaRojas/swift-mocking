
import XCTest
@testable import SwiftMocking

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

    func testSubscript_Supports_Overloaded_Functions() {
        let mock = Mock()
        let _: Spy<Int, None, Void> = mock.myFunction
        let _: Spy<String, None, Void> = mock.myFunction
        XCTAssertEqual(mock.spies.values.reduce(0, { $0 + $1.count }), 2)
        let _: Spy<Int, None, Void> = Mock.myFunction
        let _: Spy<String, None, Void> = Mock.myFunction
        XCTAssertEqual(Mock.spies.values.reduce(0, { $0 + $1.count }), 2)
    }

    func testClear_ClearsAllSpies() {
        let mock = Mock()
        let spy1: Spy<Int, None, Void> = mock.myFunction
        let spy2: Spy<String, None, Void> = mock.anotherFunction

        spy1.call(42)
        spy2.call("test")

        XCTAssertEqual(spy1.invocations.count, 1)
        XCTAssertEqual(spy2.invocations.count, 1)

        mock.clear()

        XCTAssertEqual(spy1.invocations.count, 0)
        XCTAssertEqual(spy2.invocations.count, 0)
        XCTAssertEqual(spy1.stubs.count, 0)
        XCTAssertEqual(spy2.stubs.count, 0)
    }

    func testStatic() {
        class LoggerMock: Mock {
            static func log(_ message: ArgMatcher<String>) -> Interaction<String, None, Void> {
                Interaction(message, spy: super.log)
            }
        }

        class PrinterMock: Mock {
            static func print(_ message: ArgMatcher<String>) -> Interaction<String, None, Void> {
                Interaction(message, spy: super.print)
            }
        }

        _ = LoggerMock.log(.any)
        _ = PrinterMock.print(.any)
        XCTAssertEqual(LoggerMock.spies.values.count, 1)
        XCTAssertEqual(PrinterMock.spies.values.count, 1)
    }

    func testLogger() async throws {
        let printExpectation = XCTestExpectation(description: "print called")
        let logExpectation = XCTestExpectation(description: "log should not be called")
        logExpectation.isInverted = true

        class LoggerMock: Mock {
            func log(_ message: ArgMatcher<String>) -> Interaction<String, None, Void> {
                Interaction(message, spy: super.log)
            }
        }

        class PrinterMock: Mock {
            func print(_ message: ArgMatcher<String>) -> Interaction<String, None, Void> {
                Interaction(message, spy: super.print)
            }
        }

        let loggerMock = LoggerMock()
        let printerMock = PrinterMock()
        printerMock.isLoggingEnabled = true
        let logInteraction = loggerMock.log(.any)
        let printInteraction = printerMock.print(.any)
        printInteraction.spy.logger = { _ in
            printExpectation.fulfill()
        }

        logInteraction.spy.logger = { _ in
            logExpectation.fulfill()
        }

        logInteraction.spy.call("")
        printInteraction.spy.call("")

        await fulfillment(of: [printExpectation, logExpectation], timeout: 1)
    }
    
    func testSubscript_race_condition() {
        let mock = Mock()
        let queue = DispatchQueue(label: "com.swiftmocking.race_condition_test", attributes: .concurrent)
        let group = DispatchGroup()
        let iterationCount = 100

        for _ in 0..<iterationCount {
            group.enter()
            queue.async {
                let _: Spy<Int, None, Void> = mock.myFunction
                group.leave()
            }
        }

        group.wait()

        XCTAssertEqual(mock.spies.count, 1)
    }
}
