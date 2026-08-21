import XCTest
@testable import SwiftMocking
import SwiftMockingTestSupport

/// Generic subscripts must carry their generic clause onto every generated
/// declaration; without it the expansion references an undeclared parameter.
///
/// Note the stubbing site needs `.any(String.self)` rather than a bare `.any`:
/// nothing else in `when(mock[...])` pins the subscript's generic parameter, so
/// the type must come from the matcher.
@Mockable
protocol GenericSubscriptService {
    subscript<T: Hashable>(item: T) -> String { get }
}

@Mockable
protocol GenericSettableSubscriptService {
    subscript<T: Hashable>(item: T) -> String { get set }
}

final class GenericSubscriptTests: MockingTestCase {
    func testGenericSubscriptReadStubsAndVerifies() {
        let mock = MockGenericSubscriptService()
        let svc: GenericSubscriptService = mock
        when(mock[.any(String.self)]).thenReturn("stubbed")

        XCTAssertEqual(svc["key"], "stubbed")
        verify(mock[.equal("key")]).called(1)
    }

    func testGenericSettableSubscriptRoundTrips() {
        let mock = MockGenericSettableSubscriptService()
        var svc: GenericSettableSubscriptService = mock
        when(mock[.any(String.self)]).thenReturn("read")

        XCTAssertEqual(svc["k"], "read")
        svc["k"] = "written"

        verify(mock[.equal("k")]).called(1)
        verify(mock[.equal("k")] <- "written").called(1)
    }
}
