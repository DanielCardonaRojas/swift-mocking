import XCTest
@testable import SwiftMocking

/// A class a protocol can constrain its conformers to.
class SampleBase {
    init() {}
}

/// The motivating case: a protocol carrying a **class constraint**.
///
/// Conformers must inherit `SampleBase`, and the default strategy needs that
/// same slot for `Mock`. Swift permits one superclass, so without
/// `.composition` the generated mock fails to compile with `requires that
/// 'MockViewControllerService' inherit from 'SampleBase'` — and no hand-edit
/// rescues it, unlike protocol inheritance where marking the parent `@Mockable`
/// works around the limitation.
@Mockable([.composition])
protocol ViewControllerService: SampleBase {
    func modified() -> Data
    func ping()
    var name: String { get }
    var flag: Bool { get set }
    static func shared() -> Int
}

/// Tests for `@Mockable([.composition])`.
///
/// These are primarily *compile-time* assertions: the snapshot tests in
/// `SwiftMockingMacrosTests` compare generated text and cannot catch output
/// that is well-formed but rejected by the compiler. That gap is what hid the
/// `mutating` bug, so the strategy is exercised here against a real protocol.
final class CompositionStrategyTests: XCTestCase {
    func testMethodStubbingAndVerification() {
        let mock = MockViewControllerService()
        when(mock.modified()).thenReturn(Data([1, 2, 3]))

        let service: ViewControllerService = mock
        let result = service.modified()

        XCTAssertEqual(Array(result), [1, 2, 3])
        verify(mock.modified()).called(1)
    }

    /// `Void` returns are the inference-sensitive case under composition: with
    /// no contextual result type the solver cannot infer the spy's `Output`.
    /// The generated `return` is what anchors it.
    func testVoidReturningMethodIsRecorded() {
        let mock = MockViewControllerService()
        let service: ViewControllerService = mock

        service.ping()

        verify(mock.ping()).called(1)
    }

    func testPropertyGetter() {
        let mock = MockViewControllerService()
        when(mock.name()).thenReturn("composed")

        let service: ViewControllerService = mock

        XCTAssertEqual(service.name, "composed")
        verify(mock.name()).called(1)
    }

    /// Settable members read their spy inside an escaping closure, where the
    /// composed strategy must spell `self.mock` — a bare `mock` is rejected
    /// with `requires explicit use of 'self'`.
    func testSettablePropertyRecordsReadsAndWrites() {
        let mock = MockViewControllerService()
        when(mock.flag()).thenReturn(true)
        var service: ViewControllerService = mock

        service.flag = false
        let read = service.flag

        XCTAssertTrue(read)
        verify(mock.flag() <- .equal(false)).called(1)
    }

    /// Static requirements resolve through the separate `staticMock` storage,
    /// since a static member cannot reach an instance property.
    func testStaticRequirement() {
        MockViewControllerService.staticMock.clear()
        when(MockViewControllerService.shared()).thenReturn(42)

        let service: ViewControllerService.Type = MockViewControllerService.self

        XCTAssertEqual(service.shared(), 42)
        verify(MockViewControllerService.shared()).called(1)
    }

    /// `verifyZeroInteractions` takes a `MockProviding`, so it accepts a
    /// composed mock directly rather than requiring `mock.mock`.
    func testVerifyZeroInteractionsAcceptsComposedMock() {
        let mock = MockViewControllerService()

        verifyZeroInteractions(mock)
    }

    /// The composed mock still satisfies its class constraint.
    func testMockIsUsableAsItsRequiredSuperclass() {
        let mock = MockViewControllerService()

        XCTAssertTrue((mock as Any) is SampleBase)
    }
}
