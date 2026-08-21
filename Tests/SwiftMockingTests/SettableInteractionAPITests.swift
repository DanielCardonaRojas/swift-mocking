import XCTest
@testable import SwiftMocking
import SwiftMockingTestSupport

/// Exercises `SettableInteraction` and `<-` directly, without the macro.
///
/// The generator does not emit `SettableInteraction` yet; this pins the runtime
/// contract the subscript and variable expansions will target — reads and writes
/// land on separate spies, and the write pack is the read pack plus the value.
private final class ManualSettableMock: Mock, @unchecked Sendable {
    // Runtime members, written the way the generator will emit them.
    var value: Int {
        get { adapt(super.value, ()) }
        set { return adapt(super.setValue, (), newValue) }
    }

    subscript(index: Int) -> String {
        get { return adapt(super.subscriptIndex, index) }
        set { return adapt(super.setSubscriptIndex, index, newValue) }
    }

    // Interaction members.
    func value(_ void: Void) -> SettableInteraction<Void, None, Int> {
        SettableInteraction(
            get: Interaction(.any, spy: super.value),
            setInteraction: { newValue in
                Interaction(.any, newValue, spy: super.setValue)
            }
        )
    }

    subscript(index: ArgMatcher<Int>) -> SettableInteraction<Int, None, String> {
        get {
            SettableInteraction(
                get: Interaction(index, spy: super.subscriptIndex),
                setInteraction: { newValue in
                    Interaction(index, newValue, spy: super.setSubscriptIndex)
                }
            )
        }
    }
}

final class SettableInteractionAPITests: MockingTestCase {
    func testVariableReadsAndWritesUseSeparateSpies() {
        let mock = ManualSettableMock()
        when(mock.value).thenReturn(7)

        XCTAssertEqual(mock.value, 7)
        mock.value = 9

        verify(mock.value).called(1)
        verify(mock.value <- 9).called(1)
        verifyNever(mock.value <- 7)
    }

    func testSubscriptReadsAndWritesUseSeparateSpies() {
        let mock = ManualSettableMock()
        when(mock[.any]).thenReturn("read")

        XCTAssertEqual(mock[1], "read")
        mock[1] = "written"

        verify(mock[.equal(1)]).called(1)
        verify(mock[.equal(1)] <- "written").called(1)
        verifyNever(mock[.equal(2)] <- .any)
    }

    func testWritePackIsReadPackPlusValue() {
        let mock = ManualSettableMock()

        mock[3] = "written"

        verify(mock[.any] <- .any).captured { index, newValue in
            XCTAssertEqual(index, 3)
            XCTAssertEqual(newValue, "written")
        }
    }

    func testWriteSideEffectRunsThroughCaptureBox() {
        let mock = ManualSettableMock()
        let written = CaptureBox<Int>()
        when(mock.value <- 7).thenReturn { _, newValue in
            written.append(newValue)
        }

        mock.value = 7
        mock.value = 8

        XCTAssertEqual(written.values, [7])
    }

    func testWritesComposeWithVerifyInOrder() {
        let mock = ManualSettableMock()

        mock.value = 1
        mock[2] = "two"

        verifyInOrder([
            mock.value <- 1,
            mock[.equal(2)] <- "two"
        ])
    }
}
