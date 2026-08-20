import XCTest
@testable import SwiftMocking
import SwiftMockingTestSupport

/// A requirement may legitimately name a parameter `newValue`. Generated code
/// must not bind the written value to that same identifier, or the index
/// matcher is shadowed and the expansion fails to compile.
@Mockable
protocol NewValueCollisionService {
    subscript(newValue: Int) -> String { get set }
    var newValue: Bool { get set }
}

final class NewValueCollisionTests: MockingTestCase {
    func testSubscriptIndexMatcherSurvivesNewValueParameterName() {
        let mock = MockNewValueCollisionService()
        var svc: NewValueCollisionService = mock
        when(mock[.any]).thenReturn("read")

        XCTAssertEqual(svc[1], "read")
        svc[1] = "written"
        svc[2] = "other"

        // The index matcher still discriminates — it was not replaced by the value.
        verify(mock[.equal(1)] <- "written").called(1)
        verify(mock[.equal(2)] <- "other").called(1)
        verifyNever(mock[.equal(1)] <- "other")
    }

    func testPropertyNamedNewValueRoundTrips() {
        let mock = MockNewValueCollisionService()
        when(mock.newValue).thenReturn(true)

        XCTAssertTrue(mock.newValue)
        mock.newValue = false

        verify(mock.newValue).called(1)
        verify(mock.newValue <- false).called(1)
    }
}
