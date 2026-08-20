import XCTest
@testable import SwiftMocking
import SwiftMockingTestSupport

@Mockable
protocol SubscriptService {
    subscript(index: Int) -> String { get }
}

@Mockable
protocol SettableSubscriptService {
    subscript(index: Int) -> String { get set }
}

/// End-to-end coverage for protocol subscript requirements.
///
/// The macro expansions are covered in `ProtocolFeaturesTests` (get-only and
/// get-set); these tests exercise the generated mocks at runtime.
///
/// Reads stub and verify through the `ArgMatcher` interaction subscript
/// (`mock[.any]`). Settable requirements surface a `SettableInteraction`:
/// reads use it directly (`when(mock[.any])`), writes verify via the
/// `assigned:` operators — `verify(mock[.any], assigned: "one")` — with the
/// written value recorded after the index on a dedicated spy.
final class SubscriptInteractionTests: MockingTestCase {
    // MARK: Get

    func testSubscriptGetter_StubbedValueIsReturned() {
        let mock = MockSubscriptService()
        let service: SubscriptService = mock
        when(mock[.any]).thenReturn("stubbed")

        let result = service[42]

        XCTAssertEqual(result, "stubbed")
    }

    func testSubscriptGetter_StubbedValueRespectsArgumentMatcher() {
        let mock = MockSubscriptService()
        let service: SubscriptService = mock
        when(mock[.equal(1)]).thenReturn("one")
        when(mock[.equal(2)]).thenReturn("two")

        XCTAssertEqual(service[1], "one")
        XCTAssertEqual(service[2], "two")
    }

    func testSubscriptGetter_InvocationIsRecordedForVerification() {
        let mock = MockSubscriptService()
        let service: SubscriptService = mock

        _ = service[1]
        _ = service[2]
        _ = service[2]

        verify(mock[.equal(1)]).called(1)
        verify(mock[.equal(2)]).called(2)
        verify(mock[.any]).called(3)
    }

    func testSubscriptGetter_NeverCalledVerification() {
        let mock = MockSubscriptService()

        verifyNever(mock[.any])
    }

    // MARK: Set

    func testSubscriptSetter_WriteIsRecordedForVerification() {
        let mock = MockSettableSubscriptService()
        var service: SettableSubscriptService = mock

        service[0] = "written"

        verify(mock[.any], assigned: .any).called(1)
    }

    func testSubscriptSetter_VerificationRespectsArgumentMatchers() {
        let mock = MockSettableSubscriptService()
        var service: SettableSubscriptService = mock

        service[1] = "one"
        service[2] = "two"
        service[2] = "two"

        verify(mock[.equal(1)], assigned: .equal("one")).called(1)
        verify(mock[.equal(2)], assigned: .equal("two")).called(2)
        verify(mock[.any], assigned: .any).called(3)
    }

    func testSubscriptSetter_NeverCalledVerification() {
        let mock = MockSettableSubscriptService()

        verifyNever(mock[.any], assigned: .any)
    }

    // MARK: Get and set are independent interactions

    func testSubscript_GetAndSetAreRecordedOnSeparateSpies() {
        let mock = MockSettableSubscriptService()
        var service: SettableSubscriptService = mock

        _ = service[1]
        service[1] = "one"
        service[2] = "two"

        verify(mock[.any]).called(1)
        verify(mock[.any], assigned: .any).called(2)
        verify(mock[.equal(1)], assigned: .any).called(1)
    }

    func testSettableSubscript_GetterStillStubbable() {
        let mock = MockSettableSubscriptService()
        let service: SettableSubscriptService = mock
        when(mock[.any]).thenReturn("stubbed")

        XCTAssertEqual(service[7], "stubbed")
        verify(mock[.any]).called(1)
    }
}
