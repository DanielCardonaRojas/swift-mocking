//
//  CrossSpyVerificationTests.swift
//  swift-mocking
//
//  Created by Claude Code
//

import XCTest
@testable import SwiftMocking

class CrossSpyVerificationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear all recorded invocations before each test
        Task {
            await InvocationRecorder.shared.clear()
        }
    }

    override func tearDown() {
        super.tearDown()
        // Clear all recorded invocations after each test
        Task {
            await InvocationRecorder.shared.clear()
        }
    }

    func test_invocationRecorder_recordsGlobally() async {
        await InvocationRecorder.shared.clear()

        let spy1 = Spy<String, None, Int>()
        let spy2 = Spy<Int, None, String>()

        spy1.configureLogger(label: "spy1.method")
        spy2.configureLogger(label: "spy2.method")

        // Execute method calls
        _ = spy1.call("test")
        _ = spy2.call(42)

        // Check that invocations were recorded globally
        let recordings = await InvocationRecorder.shared.snapshot()
        XCTAssertEqual(recordings.count, 2)

        // Check that the order is preserved
        XCTAssertEqual(recordings[0].index, 0)
        XCTAssertEqual(recordings[1].index, 1)

        // Check that different spies have different IDs
        XCTAssertNotEqual(recordings[0].spyID, recordings[1].spyID)
    }

    func test_invocationRecorder_clearFunctionality() async {
        let spy = Spy<String, None, Int>()
        spy.configureLogger(label: "test.method")

        _ = spy.call("test")

        // Verify recording exists
        let recordingsBefore = await InvocationRecorder.shared.snapshot()
        XCTAssertEqual(recordingsBefore.count, 1)

        // Clear and verify empty
        await InvocationRecorder.shared.clear()
        let recordingsAfter = await InvocationRecorder.shared.snapshot()
        XCTAssertEqual(recordingsAfter.count, 0)
    }

    func test_spyID_uniqueness() {
        let spy1 = Spy<String, None, Int>()
        let spy2 = Spy<String, None, Int>()
        let spy3 = Spy<Int, None, String>()

        // Each spy should have a unique ID
        XCTAssertNotEqual(spy1.spyID, spy2.spyID)
        XCTAssertNotEqual(spy1.spyID, spy3.spyID)
        XCTAssertNotEqual(spy2.spyID, spy3.spyID)
    }

    func test_methodLabel_setCorrectly() {
        let spy1 = Spy<String, None, Int>()
        let spy2 = Spy<Int, None, String>()

        spy1.configureLogger(label: "TestClass.method1")
        spy2.configureLogger(label: "TestClass.method2")

        // Method labels should be set correctly
        XCTAssertEqual(spy1.methodLabel, "TestClass.method1")
        XCTAssertEqual(spy2.methodLabel, "TestClass.method2")
    }

    func test_crossSpyVerificationEngine_basicFunctionality() async {
        await InvocationRecorder.shared.clear()

        let spy1 = Spy<String, None, Int>()
        let spy2 = Spy<Int, None, String>()

        spy1.configureLogger(label: "spy1.method")
        spy2.configureLogger(label: "spy2.method")

        // Execute method calls in specific order
        _ = spy1.call("first")
        _ = spy2.call(42)
        _ = spy1.call("second")

        // Create verification objects manually
        let interaction1 = Interaction(.any, spy: spy1)
        let interaction2 = Interaction(.any, spy: spy2)
        let interaction3 = Interaction(.any, spy: spy1)

        // Test cross-spy verification
        let verifiables: [any CrossSpyVerifiable] = [interaction1, interaction2, interaction3]
        let success = CrossSpyVerificationEngine.verifyInOrder(verifiables)
        XCTAssertTrue(success, "Cross-spy verification should succeed for correct order")
    }

    func test_crossSpyVerificationEngine_failsWhenOrderIsWrong() async {
        await InvocationRecorder.shared.clear()

        let spy1 = Spy<String, None, Int>()
        let spy2 = Spy<Int, None, String>()

        spy1.configureLogger(label: "spy1.method")
        spy2.configureLogger(label: "spy2.method")

        // Execute in one order
        _ = spy1.call("first")
        _ = spy2.call(42)

        // Create verification objects in wrong order
        let interaction1 = Interaction(.any, spy: spy2)  // Wrong order - spy2 before spy1
        let interaction2 = Interaction(.any, spy: spy1)

        let verifiables: [any CrossSpyVerifiable] = [interaction1, interaction2]
        let success = CrossSpyVerificationEngine.verifyInOrder(verifiables)
        XCTAssertFalse(success, "Verification should fail when order is incorrect")
    }

    func test_crossSpyVerificationEngine_partialMatch() async {
        await InvocationRecorder.shared.clear()

        let spy1 = Spy<String, None, Int>()
        let spy2 = Spy<Int, None, String>()

        spy1.configureLogger(label: "spy1.method")
        spy2.configureLogger(label: "spy2.method")

        // Execute only partial sequence
        _ = spy1.call("first")
        // Missing spy2 call

        // Create verification for both calls
        let interaction1 = Interaction(.any, spy: spy1)
        let interaction2 = Interaction(.any, spy: spy2)  // This call never happened

        let verifiables: [any CrossSpyVerifiable] = [interaction1, interaction2]
        let success = CrossSpyVerificationEngine.verifyInOrder(verifiables)
        XCTAssertFalse(success, "Verification should fail when expected calls are missing")
    }

    func test_crossSpyVerificationEngine_emptySequence() {
        // Empty verification should always succeed
        let success = CrossSpyVerificationEngine.verifyInOrder([])
        XCTAssertTrue(success, "Empty verification should always succeed")
    }

    func test_interaction_conformsToCrossSpyVerifiable() {
        let spy = Spy<String, None, Int>()
        spy.configureLogger(label: "test.method")

        let interaction = Interaction(.any, spy: spy)

        // Test that Interaction conforms to CrossSpyVerifiable
        XCTAssertEqual(interaction.spyID, spy.spyID)
        XCTAssertEqual(interaction.methodLabel, spy.methodLabel)

        // Create a mock recorded entry
        let recorded = Recorded(
            index: 0,
            spyID: spy.spyID,
            invocationID: UUID(),
            methodLabel: spy.methodLabel,
            arguments: ["test"]
        )

        // Test matching
        XCTAssertTrue(interaction.matches(recorded))
    }

    func test_recorded_initialization() {
        let spyID = UUID()
        let invocationID = UUID()
        let methodLabel = "Test.method"
        let arguments: [Any] = ["arg1", 42, true]

        let recorded = Recorded(
            index: 5,
            spyID: spyID,
            invocationID: invocationID,
            methodLabel: methodLabel,
            arguments: arguments
        )

        XCTAssertEqual(recorded.index, 5)
        XCTAssertEqual(recorded.spyID, spyID)
        XCTAssertEqual(recorded.invocationID, invocationID)
        XCTAssertEqual(recorded.methodLabel, methodLabel)
        XCTAssertEqual(recorded.arguments.count, 3)
    }
}