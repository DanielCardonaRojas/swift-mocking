import XCTest
@testable import SwiftMocking

// MARK: - Actor shape matrix
//
// One `Actor`-inheriting protocol per generation-relevant shape. A protocol
// inheriting `Actor` can only be satisfied by an `actor` — `error: non-actor
// type 'MockX' cannot conform to the 'Actor' protocol` — so the generator emits
// an actor declaration and marks every instance member `nonisolated`.
//
// Like the composition matrix, the value here is largely in *compiling*: every
// failure mode of this shape is a compile error whose generated text looks
// correct. `required` on an actor, a `super.init()` with no superclass, a `final
// actor`, and a missing `nonisolated` are all invisible to a snapshot test.
//
// The `nonisolated` cases are the subtle ones. An actor-isolated witness
// compiles at the *declaration* and fails only at the call site (`error: call to
// actor-isolated instance method 'ping' in a synchronous nonisolated context`),
// so these tests deliberately stub, call, and verify from a synchronous,
// non-`async` test body. An `async` test body would mask the bug entirely.

@Mockable()
protocol SyncActorShape: Actor {
    func ping() -> Bool
}

@Mockable()
protocol AsyncThrowingActorShape: Actor {
    func fetch(from id: String) async throws -> Data
}

@Mockable()
protocol PropertyActorShape: Actor {
    var name: String { get }
    var retries: Int { get set }
}

@Mockable()
protocol SubscriptActorShape: Actor {
    subscript(index: Int) -> String { get }
}

@Mockable()
protocol StaticActorShape: Actor {
    static func reset() -> Int
}

/// An actor protocol inheriting another protocol alongside `Actor`.
///
/// Only `Actor`/`AnyActor`/`Sendable` are dropped from the restated inheritance
/// clause; everything else must survive, or the mock fails to conform.
@Mockable()
protocol NamedActorShape: Actor, Identifiable {
    var id: String { get }
}

/// An actor protocol with an `init` requirement.
///
/// Pins both halves of the initializer rule: no `required` (`error: 'required'
/// initializer in non-class type`) and no `super.init()` (an actor is a root
/// type). It also pins that the synthesized zero-argument `init()` is still
/// emitted — the conservative "composed protocol has a non-empty inheritance
/// clause" test would otherwise suppress it, since `: Actor` *is* non-empty.
@Mockable()
protocol InitializerActorShape: Actor {
    init(value: Int)
}

/// Exercises each shape in the matrix above.
final class ActorShapeMatrixTests: XCTestCase {
    /// Deliberately **not** `async`: a synchronous body is what proves the
    /// generated members are `nonisolated`.
    func testSyncMethod() {
        let mock = MockSyncActorShape()
        when(mock.ping()).thenReturn(true)

        XCTAssertTrue(mock.ping())
        verify(mock.ping()).called(1)
    }

    func testAsyncThrowing() async throws {
        let mock = MockAsyncThrowingActorShape()
        when(mock.fetch(from: .any)).thenReturn(Data([1]))

        let service: AsyncThrowingActorShape = mock
        let result = try await service.fetch(from: "id")

        XCTAssertEqual(Array(result), [1])
        verify(mock.fetch(from: .equal("id"))).called(1)
    }

    func testGetOnlyProperty() {
        let mock = MockPropertyActorShape()
        when(mock.name()).thenReturn("session")

        XCTAssertEqual(mock.name, "session")
        verify(mock.name()).called(1)
    }

    /// Settable members read their spy inside an escaping closure, the case that
    /// forces `self.mock` in generated code — and on an actor that closure also
    /// has to reach `nonisolated` storage.
    func testSettableProperty() {
        let mock = MockPropertyActorShape()
        when(mock.retries()).thenReturn(3)

        XCTAssertEqual(mock.retries, 3)
        mock.retries = 5

        verify(mock.retries(()).set(.equal(5))).called(1)
    }

    func testSubscriptGetter() {
        let mock = MockSubscriptActorShape()
        when(mock[.equal(1)]).thenReturn("one")

        XCTAssertEqual(mock[1], "one")
        verify(mock[.equal(1)]).called(1)
    }

    /// Static members of an actor are already nonisolated, so they carry no
    /// added modifier and reach `staticMock` rather than `self.mock`.
    func testStaticMethod() {
        MockStaticActorShape.clear()
        when(MockStaticActorShape.reset()).thenReturn(9)

        XCTAssertEqual(MockStaticActorShape.reset(), 9)
        verify(MockStaticActorShape.reset()).called(1)
    }

    func testInheritedProtocolIsRestated() {
        let mock = MockNamedActorShape()
        when(mock.id()).thenReturn("abc")

        XCTAssertEqual(mock.id, "abc")
        verify(mock.id()).called(1)
    }

    /// The synthesized `init()` is what every other test in this file relies on;
    /// this one pins that it survives alongside a declared `init(value:)` and
    /// that the declared initializer still records.
    func testInitializerRequirementRecords() {
        MockInitializerActorShape.clear()

        _ = MockInitializerActorShape(value: 7)

        verify(MockInitializerActorShape.`init`(value: .equal(7))).called(1)

        // The zero-argument initializer exists even though the protocol only
        // declares `init(value:)`.
        _ = MockInitializerActorShape()
    }

    /// `MockProviding` is satisfied by the `nonisolated let mock`, so `clear()`
    /// and `verifyZeroInteractions` work synchronously on an actor mock.
    func testMockProvidingConformance() {
        let mock = MockSyncActorShape()
        when(mock.ping()).thenReturn(true)
        let called: Bool = mock.ping()
        XCTAssertTrue(called)

        mock.clear()

        verifyZeroInteractions(mock)
    }
}
