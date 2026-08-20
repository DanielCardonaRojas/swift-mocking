import XCTest
@testable import SwiftMocking
import SwiftMockingTestSupport

@Mockable
protocol MutableService {
    var value: Int { get set }
    var cachePolicy: String { get set }
    func refresh()
}

/// End-to-end coverage for settable variable requirements.
///
/// Settable variables surface a `SettableInteraction` through their getter
/// interaction member (`mock.value`): reads stub and verify unchanged
/// (`when(mock.value)` / `verify(mock.value)`), writes build a plain write
/// interaction with the `<-` operator, and the result composes with
/// `verifyInOrder` and `captured`. Writes record `(Void, newValue)` — the
/// read pack plus the written value.
///
/// These drive the mock directly (`mock.value = 7`) rather than through a
/// protocol-typed reference: for a *property*, the runtime member is a `var`
/// and the interaction member is a `func`, so neither reads nor writes are
/// ambiguous. Zero-arg *methods* like `refresh()` do need the protocol type.
final class SettablePropertyInteractionTests: MockingTestCase {
    func testPropertyGetter_StillStubbedThroughWrapper() {
        let mock = MockMutableService()
        when(mock.value).thenReturn(7)

        XCTAssertEqual(mock.value, 7)
        verify(mock.value).called(1)
    }

    func testPropertyWrite_VerifiedWithAssigned() {
        let mock = MockMutableService()
        mock.value = 7

        verify(mock.value <- 7).called(1)
    }

    func testPropertyWrite_AssignedAcceptsLiteralMatcher() {
        let mock = MockMutableService()
        mock.value = 7
        mock.value = 9
        verify(mock.value <- 7).called(1)
        verify(mock.value <- .greaterThan(8)).called(1)
    }

    func testPropertyWrite_VerificationRespectsExplicitSetForm() {
        let mock = MockMutableService()

        mock.value = 7
        mock.value = 9
        mock.value = 9

        verify(mock.value(()).set(.equal(7))).called(1)
        verify(mock.value(()).set(.equal(9))).called(2)
    }

    func testPropertyWrite_NeverAssigned() {
        let mock = MockMutableService()

        verifyNever(mock.value <- .any)
    }

    func testPropertyWrite_StubbedSideEffectRunsOnAssignment() {
        let mock = MockMutableService()
        let written = CaptureBox<Int>()
        when(mock.value <- 7).thenReturn { _, newValue in
            written.append(newValue)
        }

        mock.value = 7
        mock.value = 8

        // Only the matched write runs the handler.
        XCTAssertEqual(written.values, [7])
    }

    func testProperty_GetAndSetAreRecordedOnSeparateSpies() {
        let mock = MockMutableService()

        _ = mock.value
        mock.value = 1
        mock.value = 2

        verify(mock.value).called(1)
        verify(mock.value <- .any).called(2)
    }

    func testPropertyWrite_ComposesWithVerifyInOrder() {
        let mock = MockMutableService()
        let service: MutableService = mock

        mock.value = 7
        // Zero-arg methods are ambiguous on the mock type (runtime vs.
        // interaction member) — unlike properties, they need the protocol type.
        service.refresh()

        verifyInOrder([
            mock.value <- 7,
            mock.refresh()
        ])
    }

    func testPropertyWrite_CapturedArgumentsIncludeNewValue() {
        let mock = MockMutableService()

        mock.value = 7

        // Writes record the read pack first, then the written value.
        verify(mock.value <- .any).captured { _, newValue in
            XCTAssertEqual(newValue, 7)
        }
    }

    /// The read and write spies must agree on a camelCase name. `String.capitalized`
    /// lowercases the tail (`cachePolicy` → `setCachepolicy`), which is self-consistent
    /// and so invisible to a round-trip test — but wrong in generated source people read.
    func testMultiWordProperty_ReadAndWriteSpiesRoundTrip() {
        let mock = MockMutableService()
        when(mock.cachePolicy).thenReturn("none")

        XCTAssertEqual(mock.cachePolicy, "none")
        mock.cachePolicy = "aggressive"

        verify(mock.cachePolicy).called(1)
        verify(mock.cachePolicy <- "aggressive").called(1)
    }

    func testPropertyRead_VerifiedThroughWrapper() {
        let mock = MockMutableService()
        let service: MutableService = mock

        // Reads also route correctly through a protocol-typed reference —
        // the shape a SUT under test actually holds.
        _ = service.value

        verify(mock.value).called(1)
    }
}
