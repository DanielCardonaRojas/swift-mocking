import XCTest
@testable import SwiftMocking

@Mockable
protocol ParameterlessService {
    func fire() -> Int
    func ping()
    var counter: Int { get }
    func refresh() async -> String
    func risky() throws -> Int
}

/// Regression tests for the empty-pack vs `(Void)`-pack spy split.
///
/// Requirements without parameters used to record invocations on a spy with an
/// empty input pack (`Spy<Pack{}, ...>`), while the generated `Interaction`
/// stubs and verifies a `(Void)`-pack spy (`Spy<Pack{()}, ...>`). The two are
/// distinct specializations, so stubs never applied and verifications read zero.
final class ParameterlessInteractionTests: XCTestCase {
    func testZeroArgMethod_StubbedValueIsReturned() {
        let mock = MockParameterlessService()
        let service: ParameterlessService = mock
        when(mock.fire()).thenReturn(42)

        let result = service.fire()

        XCTAssertEqual(result, 42)
    }

    func testZeroArgMethod_InvocationIsRecordedForVerification() {
        let mock = MockParameterlessService()
        let service: ParameterlessService = mock

        service.ping()

        verify(mock.ping()).called(1)
    }

    func testPropertyGetter_StubbedValueIsReturned() {
        let mock = MockParameterlessService()
        let service: ParameterlessService = mock
        when(mock.getCounter()).thenReturn(7)

        let result = service.counter

        XCTAssertEqual(result, 7)
    }

    func testPropertyGetter_InvocationIsRecordedForVerification() {
        let mock = MockParameterlessService()
        let service: ParameterlessService = mock

        _ = service.counter

        verify(mock.getCounter()).called(1)
    }

    func testZeroArgAsyncMethod_StubbedValueIsReturned() async {
        let mock = MockParameterlessService()
        let service: ParameterlessService = mock
        when(mock.refresh()).thenReturn("refreshed")

        let result = await service.refresh()

        XCTAssertEqual(result, "refreshed")
    }

    func testZeroArgThrowingMethod_StubbedValueIsReturned() throws {
        let mock = MockParameterlessService()
        let service: ParameterlessService = mock
        when(mock.risky()).thenReturn(9)

        let result = try service.risky()

        XCTAssertEqual(result, 9)
    }
}
