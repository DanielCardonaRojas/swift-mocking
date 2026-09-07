import XCTest
@testable import SwiftMocking

@Mockable
protocol InitializerRepository {
    init(value: Int)
    func load() -> String
}

@Mockable
protocol MultiInitializerRepository {
    init(name: String)
    init(name: String, count: Int)
}

@Mockable
protocol ParameterlessInitializerRepository {
    init()
}

/// Declares `init()` *and* a parameterized initializer.
///
/// The synthesized zero-argument initializer must be suppressed by the `init()`
/// requirement regardless of declaration order. Tracking only "declares a
/// parameterized init" emitted both, which is
/// `error: 'init()' has already been overridden`.
@Mockable
protocol MixedInitializerRepository {
    init()
    init(value: Int)
}

/// Tests for `init` requirements under the default (inheriting) strategy.
///
/// Two defects motivated these. Declaring `required init(value:)` suppressed the
/// zero-argument initializer the mock would otherwise have, so `MockX()` did not
/// compile at all; and the generated initializer had an empty body, so
/// construction was the one requirement kind that recorded nothing and could
/// never be verified.
///
/// Recording goes through *static* storage, because an initializer runs before
/// the instance — and therefore before instance spy storage — exists. Each test
/// clears that storage first, since it outlives any single mock instance.
final class InitializerRequirementTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockInitializerRepository.clear()
        MockMultiInitializerRepository.clear()
        MockParameterlessInitializerRepository.clear()
    }

    func testInitializerRecordsItsArguments() {
        _ = MockInitializerRepository(value: 7)

        verify(MockInitializerRepository.`init`(value: .equal(7))).called(1)
    }

    func testInitializerDoesNotRecordUnmatchedArguments() {
        _ = MockInitializerRepository(value: 7)

        verify(MockInitializerRepository.`init`(value: .equal(8))).called(0)
    }

    func testInitializerRecordsEachConstruction() {
        _ = MockInitializerRepository(value: 1)
        _ = MockInitializerRepository(value: 1)
        _ = MockInitializerRepository(value: 2)

        verify(MockInitializerRepository.`init`(value: .equal(1))).called(2)
        verify(MockInitializerRepository.`init`(value: .any)).called(3)
    }

    /// The zero-argument initializer that keeps the mock constructible.
    ///
    /// Without it this line fails to compile with `missing argument for
    /// parameter 'value'`. It is not a protocol requirement, so it records
    /// nothing.
    func testMockRemainsDefaultConstructible() {
        let mock = MockInitializerRepository()

        verify(MockInitializerRepository.`init`(value: .any)).called(0)
        when(mock.load()).thenReturn("loaded")
        XCTAssertEqual(mock.load(), "loaded")
    }

    /// A mock built through the requirement's initializer is a working mock, not
    /// merely a recorded call: its instance spies are wired up as usual.
    func testMockBuiltThroughRequirementInitializerStubsNormally() {
        let mock = MockInitializerRepository(value: 3)
        when(mock.load()).thenReturn("loaded")

        let repository: InitializerRepository = mock

        XCTAssertEqual(repository.load(), "loaded")
        verify(MockInitializerRepository.`init`(value: .equal(3))).called(1)
    }

    /// Construction through a generic context, which is where an `init`
    /// requirement earns its place in a protocol.
    func testInitializerCalledThroughGenericContext() {
        func build<R: InitializerRepository>(_: R.Type) -> R { R(value: 42) }

        _ = build(MockInitializerRepository.self)

        verify(MockInitializerRepository.`init`(value: .equal(42))).called(1)
    }

    /// Overloaded initializers share one spy name (`init`) but differ in their
    /// input packs, so `Mock`'s storage keeps them as separate spies and each
    /// verifies independently.
    func testOverloadedInitializersRecordSeparately() {
        _ = MockMultiInitializerRepository(name: "a")
        _ = MockMultiInitializerRepository(name: "b", count: 2)
        _ = MockMultiInitializerRepository(name: "c", count: 3)

        verify(MockMultiInitializerRepository.`init`(name: .equal("a"))).called(1)
        verify(MockMultiInitializerRepository.`init`(name: .any)).called(1)
        verify(
            MockMultiInitializerRepository.`init`(name: .any, count: .any)
        ).called(2)
        verify(
            MockMultiInitializerRepository.`init`(name: .equal("b"), count: .equal(2))
        ).called(1)
    }

    /// A protocol that declares `init()` itself needs no *extra* zero-argument
    /// initializer — the requirement already provides one, and emitting a second
    /// would be an invalid redeclaration. Here construction *is* recorded,
    /// unlike the synthesized `init()` above.
    func testParameterlessInitializerRequirementIsRecorded() {
        _ = MockParameterlessInitializerRepository()

        verify(MockParameterlessInitializerRepository.`init`()).called(1)
    }

    /// A protocol declaring both `init()` and `init(value:)` gets exactly one
    /// zero-argument initializer — the requirement's, which records. This is
    /// primarily a compile-time assertion; emitting a second was an error.
    func testMixedInitializersEmitOneZeroArgumentInitializer() {
        MockMixedInitializerRepository.clear()

        _ = MockMixedInitializerRepository()
        _ = MockMixedInitializerRepository(value: 9)

        verify(MockMixedInitializerRepository.`init`()).called(1)
        verify(MockMixedInitializerRepository.`init`(value: .equal(9))).called(1)
    }
}
