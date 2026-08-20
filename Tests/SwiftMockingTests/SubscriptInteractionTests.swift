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

@Mockable
protocol MatrixService {
    subscript(row: Int, column: Int) -> String { get set }
}

/// End-to-end coverage for protocol subscript requirements.
///
/// The macro expansions are covered in `ProtocolFeaturesTests` (get-only and
/// get-set); these tests exercise the generated mocks at runtime.
///
/// Reads stub and verify through the `ArgMatcher` interaction subscript
/// (`mock[.any]`). Settable requirements surface a `SettableInteraction`:
/// reads use it directly (`when(mock[.any])`), writes build a plain write
/// interaction with the `<-` operator — `verify(mock[.any] <- "one")` —
/// recording the written value after the index on a dedicated spy.
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

        verify(mock[.any] <- .any).called(1)
    }

    func testSubscriptSetter_VerificationRespectsArgumentMatchers() {
        let mock = MockSettableSubscriptService()
        var service: SettableSubscriptService = mock

        service[1] = "one"
        service[2] = "two"
        service[2] = "two"

        verify(mock[.equal(1)].set(.equal("one"))).called(1)
        verify(mock[.equal(2)] <- .equal("two")).called(2)
        verify(mock[.any] <- .any).called(3)
    }

    func testSubscriptSetter_NeverCalledVerification() {
        let mock = MockSettableSubscriptService()

        verifyNever(mock[.any] <- .any)
    }

    // MARK: Get and set are independent interactions

    func testSubscript_GetAndSetAreRecordedOnSeparateSpies() {
        let mock = MockSettableSubscriptService()
        var service: SettableSubscriptService = mock

        _ = service[1]
        service[1] = "one"
        service[1] = "one"
        service[2] = "two"

        verify(mock[.any]).called(1)
        verify(mock[.equal(1)] <- "one").called(2)
        verify(mock[.equal(2)] <- "two").called()
        verify(mock[.any] <- .any).called(3)
    }

    func testSettableSubscript_GetterStillStubbable() {
        let mock = MockSettableSubscriptService()
        let service: SettableSubscriptService = mock
        when(mock[.any]).thenReturn("stubbed")

        XCTAssertEqual(service[7], "stubbed")
        verify(mock[.any]).called(1)
    }

    func testMultiParameterSubscript_SpyNamedFromConcatenatedParameters() {
        let mock = MockMatrixService()
        var service: MatrixService = mock
        when(mock[.any, .any]).thenReturn("cell")

        XCTAssertEqual(service[1, 2], "cell")
        service[1, 2] = "written"

        verify(mock[.equal(1), .equal(2)]).called(1)
        // Bind first: forwarding a pack-rearranged result (`Interaction<I…, O,
        // None, Void>`) straight into another generic call does not infer for
        // multi-index packs on this toolchain. Single-index subscripts and
        // variables ((Void) packs) chain fine: `verify(mock[.any] <- "one")`.
        let write = mock[.equal(1), .equal(2)] <- "written"
        verify(write).called(1)
        verifyNever(mock[.equal(2), .equal(1)])
    }
}
