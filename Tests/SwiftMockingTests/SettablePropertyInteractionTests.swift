import XCTest
@testable import SwiftMocking
import SwiftMockingTestSupport

@Mockable
protocol MutableService {
    var value: Int { get set }
    func refresh()
}

/// End-to-end coverage for settable variable requirements.
///
/// Settable variables surface a `SettableInteraction` through their getter
/// interaction member (`mock.value`): reads stub and verify unchanged
/// (`when(mock.value)` / `verify(mock.value)`), writes verify through the
/// `assigned:` operators, and `set(_:)` composes with `verifyInOrder` and
/// `captured`. Writes record `(Void, newValue)` — the read pack plus the
/// written value.
final class SettablePropertyInteractionTests: MockingTestCase {
    func testPropertyGetter_StillStubbedThroughWrapper() {
        let mock = MockMutableService()
        let service: MutableService = mock
        when(mock.value).thenReturn(7)

        XCTAssertEqual(service.value, 7)
        verify(mock.value).called(1)
    }

    func testPropertyWrite_VerifiedWithAssigned() {
        let mock = MockMutableService()
        var service: MutableService = mock

        service.value = 7

        verify(mock.value, assigned: .equal(7)).called(1)
    }

    func testPropertyWrite_AssignedAcceptsLiteralMatcher() {
        let mock = MockMutableService()
        var service: MutableService = mock

        service.value = 7
        service.value = 9

        verify(mock.value, assigned: 7).called(1)
        verify(mock.value, assigned: .greaterThan(8)).called(1)
    }

    func testPropertyWrite_NeverAssigned() {
        let mock = MockMutableService()

        verifyNever(mock.value, assigned: .any)
    }

    func testPropertyWrite_StubbedSideEffectRunsOnAssignment() {
        let mock = MockMutableService()
        var service: MutableService = mock
        final class CaptureBox: @unchecked Sendable {
            private let lock = NSLock()
            private var items: [Int] = []
            func append(_ item: Int) {
                lock.lock()
                defer { lock.unlock() }
                items.append(item)
            }
            var recorded: [Int] {
                lock.lock()
                defer { lock.unlock() }
                return items
            }
        }
        let written = CaptureBox()
        when(mock.value, assigned: .equal(7)).thenReturn { _, newValue in
            written.append(newValue)
        }

        service.value = 7
        service.value = 8

        XCTAssertEqual(written.recorded, [7])
    }

    func testProperty_GetAndSetAreRecordedOnSeparateSpies() {
        let mock = MockMutableService()
        var service: MutableService = mock

        _ = service.value
        service.value = 1
        service.value = 2

        verify(mock.value).called(1)
        verify(mock.value, assigned: .any).called(2)
    }

    func testPropertyWrite_ComposesWithVerifyInOrder() {
        let mock = MockMutableService()
        var service: MutableService = mock

        service.value = 7
        service.refresh()

        verifyInOrder([
            mock.value(()).set(.equal(7)),
            mock.refresh()
        ])
    }

    func testPropertyWrite_CapturedArgumentsIncludeNewValue() {
        let mock = MockMutableService()
        var service: MutableService = mock

        service.value = 7

        verify(mock.value, assigned: .any).captured { _, newValue in
            XCTAssertEqual(newValue, 7)
        }
    }

    func testPropertyRead_VerifiedThroughWrapper() {
        let mock = MockMutableService()
        let service: MutableService = mock

        _ = service.value

        verify(mock.value).called(1)
    }
}
