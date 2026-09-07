import XCTest
@testable import SwiftMocking

// MARK: - Shape matrix
//
// One class-constrained protocol per generation-relevant shape, each mocked with
// `.composition`. Their value is largely in *compiling*: the composed strategy
// rewrites every spy reference and adapter call, so a shape that the default
// strategy handles can still break here. Snapshot tests cannot catch that — the
// generated text looks correct and simply fails to build, which is how the
// initializer bug below went unnoticed.

/// A superclass with a zero-argument initializer.
class ShapeBase {
    init() {}
}

/// A superclass *without* a zero-argument initializer.
///
/// Deliberately unused by any `@Mockable` protocol in this file. A composed mock
/// chains to `super.init()`, which this class cannot satisfy, so a protocol
/// constrained to it does not compile — the documented limit of initializer
/// support under `.composition`. See `testInitializerRequirementRecords`.
class ConfiguredBase {
    init(config: Int) {}
}

@Mockable([.composition])
protocol AsyncThrowingShape: ShapeBase {
    func fetch(from id: String) async throws -> Data
}

@Mockable([.composition])
protocol VariadicShape: ShapeBase {
    func record(_ values: String...)
}

@Mockable([.composition])
protocol GenericMethodShape: ShapeBase {
    func encode<T: Encodable>(_ value: T) -> Data
}

@Mockable([.composition])
protocol SubscriptShape: ShapeBase {
    subscript(index: Int) -> String { get }
}

@Mockable([.composition])
protocol SettableSubscriptShape: ShapeBase {
    subscript(row: Int, column: Int) -> String { get set }
}

@Mockable([.composition])
protocol EscapingClosureShape: ShapeBase {
    func execute(completion: @escaping (String) -> Void)
}

@Mockable([.composition])
protocol StaticShape: ShapeBase {
    static func reset() -> Int
}

/// A protocol whose *only* static member is a subscript.
///
/// `hasStaticMembers` originally inspected functions and variables but not
/// subscripts, so this shape generated members reading `staticMock` without
/// declaring it. Static functions masked the gap — this protocol deliberately
/// has none.
@Mockable([.composition])
protocol StaticSubscriptShape: ShapeBase {
    static subscript(index: Int) -> String { get }
}

@Mockable([.composition])
protocol InitializerShape: ShapeBase {
    init(value: Int)
}

/// A composed protocol with *no* inheritance clause and an `init` requirement.
///
/// The mock is a root class, so neither generated initializer may chain to a
/// superclass and the synthesized `init()` is not an `override`.
@Mockable([.composition])
protocol RootInitializerShape {
    init(value: Int)
}

/// Exercises each shape in the matrix above.
///
/// Every test here would have passed as a no-op if the file merely compiled, so
/// each one also round-trips the mock — stub, call through a protocol-typed
/// reference, verify — to prove the composed spy wiring is connected and not
/// just syntactically valid.
final class CompositionShapeMatrixTests: XCTestCase {
    func testAsyncThrowing() async throws {
        let mock = MockAsyncThrowingShape()
        when(mock.fetch(from: .any)).thenReturn(Data([1]))

        let service: AsyncThrowingShape = mock
        let result = try await service.fetch(from: "id")

        XCTAssertEqual(Array(result), [1])
        verify(mock.fetch(from: .equal("id"))).called(1)
    }

    func testVariadic() {
        let mock = MockVariadicShape()
        let service: VariadicShape = mock

        service.record("a", "b")

        verify(mock.record(.equal("a"), .equal("b"))).called(1)
    }

    func testGenericMethod() {
        let mock = MockGenericMethodShape()
        when(mock.encode(.any(Int.self))).thenReturn(Data([2]))

        let result: Data = mock.encode(7)

        XCTAssertEqual(Array(result), [2])
        verify(mock.encode(.any(Int.self))).called(1)
    }

    func testSubscriptGetter() {
        let mock = MockSubscriptShape()
        when(mock[.equal(1)]).thenReturn("one")

        let service: SubscriptShape = mock

        XCTAssertEqual(service[1], "one")
        verify(mock[.equal(1)]).called(1)
    }

    /// Settable members read their spy inside an escaping closure, the case that
    /// forces `self.mock` rather than a bare `mock` in generated code.
    func testSettableSubscript() {
        let mock = MockSettableSubscriptShape()
        when(mock[.any, .any]).thenReturn("read")
        var service: SettableSubscriptShape = mock

        service[1, 2] = "written"
        let read = service[1, 2]

        XCTAssertEqual(read, "read")
        verify(mock[.equal(1), .equal(2)]).called(1)
        // Annotated for the same reason as the multi-index case in
        // `SubscriptInteractionTests`: `<-` returns
        // `Interaction<repeat each Input, Output, None, Void>`, and splitting a
        // concrete `Int, Int, String` back into `each Input` plus `Output` is
        // not inferable. Pre-existing, not specific to `.composition`.
        let write: Interaction<Int, Int, String, None, Void> =
            mock[.equal(1), .equal(2)] <- "written"
        verify(write).called(1)
    }

    func testEscapingClosureParameter() {
        let mock = MockEscapingClosureShape()
        let service: EscapingClosureShape = mock

        service.execute(completion: { _ in })

        verify(mock.execute(completion: .any)).called(1)
    }

    func testStatic() {
        MockStaticShape.staticMock.clear()
        when(MockStaticShape.reset()).thenReturn(3)

        let service: StaticShape.Type = MockStaticShape.self

        XCTAssertEqual(service.reset(), 3)
        verify(MockStaticShape.reset()).called(1)
    }

    /// Regression: a protocol whose only static member is a subscript must
    /// still get `staticMock`. Before the fix this file did not compile —
    /// `cannot find 'staticMock' in scope`.
    func testStaticSubscript() {
        MockStaticSubscriptShape.staticMock.clear()
        when(MockStaticSubscriptShape[.equal(1)]).thenReturn("one")

        let service: StaticSubscriptShape.Type = MockStaticSubscriptShape.self

        XCTAssertEqual(service[1], "one")
        verify(MockStaticSubscriptShape[.equal(1)]).called(1)
    }

    /// A composed mock inherits its protocol's required superclass, so its
    /// initializer must chain to `super.init()`. That constrains the superclass
    /// to one with a zero-argument initializer — the macro never sees it and so
    /// cannot pass arguments. `ConfiguredBase` above is the case that does not
    /// compile.
    ///
    /// Construction records on static storage, since instance storage does not
    /// exist while an initializer runs.
    func testInitializerRequirementRecords() {
        MockInitializerShape.staticMock.clear()

        _ = MockInitializerShape(value: 7)

        verify(MockInitializerShape.`init`(value: .equal(7))).called(1)
        verify(MockInitializerShape.`init`(value: .equal(8))).called(0)
    }

    /// The zero-argument `init()` a mock needs to stay constructible.
    ///
    /// Declaring `init(value:)` suppresses the initializer the mock would
    /// otherwise get, so without the generated `init()` this line fails with
    /// `missing argument for parameter 'value'`.
    ///
    /// Only a composed protocol with no inheritance clause gets one: with a
    /// non-empty clause the macro cannot tell a class parent from a protocol
    /// one, and `init()` needs `override` for the first and must not have it for
    /// the second. `MockInitializerShape` is therefore constructed only through
    /// its requirement's initializer.
    func testRootInitializerShapeRemainsDefaultConstructible() {
        MockRootInitializerShape.staticMock.clear()

        _ = MockRootInitializerShape()

        verify(MockRootInitializerShape.`init`(value: .any)).called(0)
    }

    /// A root composed mock records construction without chaining to any
    /// superclass.
    func testRootInitializerRequirementRecords() {
        MockRootInitializerShape.staticMock.clear()

        _ = MockRootInitializerShape(value: 4)

        verify(MockRootInitializerShape.`init`(value: .equal(4))).called(1)
    }
}
