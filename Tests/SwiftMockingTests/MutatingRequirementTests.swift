import XCTest
@testable import SwiftMocking

@Mockable
protocol MutatingRepository {
    mutating func save(_ value: String)
    mutating func count() -> Int
    static func reset()
}

/// Regression tests for `mutating` requirements.
///
/// The generator copied protocol modifiers verbatim onto the generated class,
/// emitting `mutating func` inside a `class` — which is not valid Swift
/// (`'mutating' is not valid on instance methods in classes`). Every mock for a
/// protocol with a `mutating` requirement therefore failed to compile.
///
/// A class satisfies a `mutating` requirement by declaring the method without
/// the modifier, so the fix is to drop it. These tests are primarily a
/// *compile-time* assertion: the snapshot tests in `SwiftMockingMacrosTests`
/// compare generated text and cannot catch output that is well-formed but
/// rejected by the compiler. Exercising the mock here proves it builds and
/// still routes through its spies.
final class MutatingRequirementTests: XCTestCase {
    func testMutatingMethod_StubbedValueIsReturned() {
        let mock = MockMutatingRepository()
        var repository: MutatingRepository = mock
        when(mock.count()).thenReturn(3)

        let result = repository.count()

        XCTAssertEqual(result, 3)
    }

    func testMutatingMethod_InvocationIsRecordedForVerification() {
        let mock = MockMutatingRepository()
        var repository: MutatingRepository = mock

        repository.save("apple")

        verify(mock.save(.equal("apple"))).called(1)
    }

    /// A `mutating` requirement is reachable through a generic context, where
    /// the call goes through a `var` binding of the concrete mock type.
    func testMutatingMethod_CalledThroughGenericContext() {
        struct System<Repository: MutatingRepository> {
            var repository: Repository
            mutating func run() { repository.save("pear") }
        }

        let mock = MockMutatingRepository()
        var system = System(repository: mock)

        system.run()

        verify(mock.save(.equal("pear"))).called(1)
    }

    /// `static` must survive the modifier filtering that removes `mutating`.
    ///
    /// The call goes through a metatype binding because a bare
    /// `MockMutatingRepository.reset()` is ambiguous between the conformance
    /// member and the interaction member, which differ only by return type.
    func testStaticRequirementIsUnaffected() {
        MockMutatingRepository.clear()
        let repository: MutatingRepository.Type = MockMutatingRepository.self

        repository.reset()

        verify(MockMutatingRepository.reset()).called(1)
    }
}
