
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import MacroTesting

final class MacroOptionsTests: MacroTestCase {
    func testPrefixMockOption() {
        assertMacro {
            """
            @Mockable([.prefixMock])
            protocol MyService {
                func doSomething()
            }
            """
        } expansion: {
            """
            protocol MyService {
                func doSomething()
            }

            #if DEBUG
            class MockMyService: Mock, @unchecked Sendable, MyService {
                func doSomething() -> Interaction<Void, None, Void> {
                    Interaction(.any, spy: super.doSomething)
                }

                func doSomething() {
                    return adapt(super.doSomething, ())
                }
            }
            #endif
            """
        }
    }

    /// `.composition` makes the mock *hold* a `Mock` instead of inheriting one,
    /// freeing the superclass slot for the class constraint the protocol
    /// imposes. Note the mock inherits `SampleBase`, reaches spies through
    /// `self.mock`, and calls the static `Mock.adapt` — a composing type
    /// inherits no instance adapters.
    func testCompositionOption() {
        assertMacro {
            """
            @Mockable([.composition])
            protocol MyService: SampleBase {
                func doSomething()
            }
            """
        } expansion: {
            """
            protocol MyService: SampleBase {
                func doSomething()
            }

            #if DEBUG
            class MockMyService: SampleBase, MyService, MockProviding, @unchecked Sendable {
                let mock = Mock()

                func doSomething() -> Interaction<Void, None, Void> {
                    Interaction(.any, spy: self.mock.doSomething)
                }

                func doSomething() {
                    return Mock.adapt(self.mock.doSomething, ())
                }
            }
            #endif
            """
        }
    }

    /// A composed protocol with no inheritance clause has no superclass to
    /// restate, so the mock can be `final` and conform to plain `Sendable`.
    ///
    /// Both are required together: a non-final class cannot conform to
    /// `Sendable`, and a `Sendable` class cannot inherit another class. The
    /// conformance is checkable rather than asserted — the mock's only storage
    /// is `let mock`, so the compiler rejects any mutable stored property.
    ///
    /// Contrast ``testCompositionOption()``, where `SampleBase` occupies the
    /// superclass slot and `@unchecked` is structurally unavoidable.
    func testCompositionWithoutInheritanceClauseIsStrictlySendable() {
        assertMacro {
            """
            @Mockable([.composition])
            protocol MyService {
                func doSomething()
            }
            """
        } expansion: {
            """
            protocol MyService {
                func doSomething()
            }

            #if DEBUG
            final class MockMyService: MyService , MockProviding, Sendable {
                let mock = Mock()

                func doSomething() -> Interaction<Void, None, Void> {
                    Interaction(.any, spy: self.mock.doSomething)
                }

                func doSomething() {
                    return Mock.adapt(self.mock.doSomething, ())
                }
            }
            #endif
            """
        }
    }

    /// A protocol with static requirements gets a second `Mock` for them:
    /// static members cannot reach an instance property. It carries the mock's
    /// own type name as its scoped storage key, so those spies land in
    /// `MockScope` — isolated by `.mocking` exactly like an inheriting mock's
    /// static spies, and reachable by `MockProviding`'s static `clear()`.
    func testCompositionOptionWithStaticRequirement() {
        assertMacro {
            """
            @Mockable([.composition])
            protocol MyService: SampleBase {
                static func reset()
            }
            """
        } expansion: {
            """
            protocol MyService: SampleBase {
                static func reset()
            }

            #if DEBUG
            class MockMyService: SampleBase, MyService, MockProviding, @unchecked Sendable {
                let mock = Mock()

                static let staticMock = Mock(scopedStorageKey: "MockMyService")

                static func reset() -> Interaction<Void, None, Void> {
                    Interaction(.any, spy: staticMock.reset)
                }

                static func reset() {
                    return Mock.adapt(staticMock.reset, ())
                }
            }
            #endif
            """
        }
    }

    /// A composed mock inherits its protocol's required superclass, so its
    /// initializer must chain to `super.init()`. The macro never sees that
    /// superclass, so this is correct exactly when the superclass has a
    /// zero-argument initializer and a compile error otherwise.
    ///
    /// Construction records on `staticMock`, which is emitted here even though
    /// the protocol declares no `static` members: instance storage does not
    /// exist yet while an initializer runs.
    ///
    /// No zero-argument `init()` is synthesized. With a non-empty inheritance
    /// clause the macro cannot tell a class parent from a protocol one, and
    /// `init()` requires `override` for the first while it must be absent for
    /// the second — see `canSynthesizeDefaultInitializer`. Contrast
    /// ``testCompositionOptionWithInitializerRequirementAndNoSuperclass()``.
    func testCompositionOptionWithInitializerRequirement() {
        assertMacro {
            """
            @Mockable([.composition])
            protocol MyService: SampleBase {
                init(value: Int)
            }
            """
        } expansion: {
            """
            protocol MyService: SampleBase {
                init(value: Int)
            }

            #if DEBUG
            class MockMyService: SampleBase, MyService, MockProviding, @unchecked Sendable {
                let mock = Mock()

                static let staticMock = Mock(scopedStorageKey: "MockMyService")

                static func `init`(value: ArgMatcher<Int>) -> Interaction<Int, None, Void> {
                    Interaction(value, spy: staticMock.`init`)
                }

                required init(value: Int) {
                    let spy: Spy<Int, None, Void> = MockMyService.staticMock.`init`
                    Mock.adapt(spy, value)
                    super.init()
                }
            }
            #endif
            """
        }
    }

    /// A composed mock for a protocol with no inherited types has no superclass
    /// at all, so neither generated initializer may chain to one:
    /// `'super' cannot be used in class 'MockMyService' because it has no
    /// superclass`. The zero-argument initializer is likewise not an `override`,
    /// since there is nothing to override.
    func testCompositionOptionWithInitializerRequirementAndNoSuperclass() {
        assertMacro {
            """
            @Mockable([.composition])
            protocol MyService {
                init(value: Int)
            }
            """
        } expansion: {
            """
            protocol MyService {
                init(value: Int)
            }

            #if DEBUG
            final class MockMyService: MyService , MockProviding, Sendable {
                let mock = Mock()

                static let staticMock = Mock(scopedStorageKey: "MockMyService")

                static func `init`(value: ArgMatcher<Int>) -> Interaction<Int, None, Void> {
                    Interaction(value, spy: staticMock.`init`)
                }

                required init(value: Int) {
                    let spy: Spy<Int, None, Void> = MockMyService.staticMock.`init`
                    Mock.adapt(spy, value)
                }

                init() {
                }
            }
            #endif
            """
        }
    }

    /// A settable property is where composition diverges most visibly: the
    /// setter interaction is built inside an escaping closure, so it reaches the
    /// write spy through a captured `self.mock` rather than through `super`.
    ///
    /// The runtime accessors likewise call the static `Mock.adapt` for both
    /// halves of the property, since a composing type inherits no instance
    /// adapters.
    func testCompositionOptionWithSettableProperty() {
        assertMacro {
            """
            @Mockable([.composition])
            protocol MyService: SampleBase {
                var value: Int { get set }
            }
            """
        } expansion: {
            """
            protocol MyService: SampleBase {
                var value: Int { get set }
            }

            #if DEBUG
            class MockMyService: SampleBase, MyService, MockProviding, @unchecked Sendable {
                let mock = Mock()

                func value(_ void: Void = ()) -> SettableInteraction<Void, None, Int > {
                    SettableInteraction(
                        get: Interaction(.any, spy: self.mock.value),
                        setInteraction: { newValue in
                            let writeSpy: Spy<Void, Int, None, Void> = self.mock.setValue
                            let writeInteraction: Interaction<Void, Int, None, Void> = Interaction(.any, newValue, spy: writeSpy)
                            return writeInteraction
                        }
                    )
                }

                var value: Int {
                    set {
                        return Mock.adapt(self.mock.setValue, (), newValue)
                    }
                    get {
                        Mock.adapt(self.mock.value, ())
                    }
                }
            }
            #endif
            """
        }
    }

    /// A protocol declaring both `init()` and a parameterized initializer gets
    /// exactly one zero-argument initializer — the requirement's, which records.
    ///
    /// Tracking only "declares a parameterized initializer" emitted a second,
    /// synthesized one: `error: 'init()' has already been overridden`.
    func testInitializerRequirementsIncludingZeroArgument() {
        assertMacro {
            """
            @Mockable
            protocol MyService {
                init()
                init(value: Int)
            }
            """
        } expansion: {
            """
            protocol MyService {
                init()
                init(value: Int)
            }

            #if DEBUG
            class MockMyService: Mock, @unchecked Sendable, MyService {
                static func `init`() -> Interaction<Void, None, Void> {
                    Interaction(.any, spy: super.`init`)
                }

                static func `init`(value: ArgMatcher<Int>) -> Interaction<Int, None, Void> {
                    Interaction(value, spy: super.`init`)
                }

                required init() {
                    let spy: Spy<Void, None, Void> = (MockMyService.self as Mock.Type).`init`
                    Mock.adapt(spy, ())
                    super.init(scopedStorageKey: nil)
                }

                required init(value: Int) {
                    let spy: Spy<Int, None, Void> = (MockMyService.self as Mock.Type).`init`
                    Mock.adapt(spy, value)
                    super.init(scopedStorageKey: nil)
                }
            }
            #endif
            """
        }
    }

    func testSuffixMockOption() {
        assertMacro {
            """
            @Mockable([.suffixMock])
            protocol MyService {
                func doSomething()
            }
            """
        } expansion: {
            """
            protocol MyService {
                func doSomething()
            }

            #if DEBUG
            class MyServiceMock: Mock, @unchecked Sendable, MyService {
                func doSomething() -> Interaction<Void, None, Void> {
                    Interaction(.any, spy: super.doSomething)
                }

                func doSomething() {
                    return adapt(super.doSomething, ())
                }
            }
            #endif
            """
        }
    }

    // MARK: - Actor-inheriting protocols

    /// A protocol inheriting `Actor` can only be satisfied by an `actor`:
    ///
    /// ```
    /// error: non-actor type 'MockSession' cannot conform to the 'Actor' protocol
    /// ```
    ///
    /// so detection switches the generated declaration kind rather than offering
    /// an option. Because an actor cannot inherit a class, this also forces the
    /// composed strategy — `self.mock` and the static `Mock.adapt` — without
    /// `.composition` being written.
    ///
    /// `Actor` is dropped from the restated inheritance clause and no `Sendable`
    /// conformance is emitted: an actor conforms to `Actor` by being one and is
    /// implicitly `Sendable`. `final` is absent for the same reason — an actor
    /// cannot be `final`.
    ///
    /// Every instance member is `nonisolated`. Without it the witness is
    /// actor-isolated, which compiles at the declaration and then fails at every
    /// synchronous call site with `error: call to actor-isolated instance method
    /// 'ping' in a synchronous nonisolated context` — making `when`/`verify`
    /// `await`-only and leaving a synchronous requirement unsatisfiable.
    func testActorInheritingProtocol() {
        assertMacro {
            """
            @Mockable()
            protocol Session: Actor {
                func ping() -> Bool
            }
            """
        } expansion: {
            """
            protocol Session: Actor {
                func ping() -> Bool
            }

            #if DEBUG
            actor MockSession: Session, MockProviding {
                nonisolated let mock = Mock()

                nonisolated func ping() -> Interaction<Void, None, Bool> {
                    Interaction(.any, spy: self.mock.ping)
                }

                nonisolated func ping() -> Bool {
                    return Mock.adapt(self.mock.ping, ())
                }
            }
            #endif
            """
        }
    }

    /// Static members of an actor are already nonisolated, so they carry no
    /// added modifier — and `staticMock` is likewise left alone.
    func testActorProtocolWithStaticRequirement() {
        assertMacro {
            """
            @Mockable()
            protocol Session: Actor {
                static func reset()
            }
            """
        } expansion: {
            """
            protocol Session: Actor {
                static func reset()
            }

            #if DEBUG
            actor MockSession: Session, MockProviding {
                nonisolated let mock = Mock()

                static let staticMock = Mock(scopedStorageKey: "MockSession")

                static func reset() -> Interaction<Void, None, Void> {
                    Interaction(.any, spy: staticMock.reset)
                }

                static func reset() {
                    return Mock.adapt(staticMock.reset, ())
                }
            }
            #endif
            """
        }
    }

    /// Only `Actor`/`AnyActor`/`Sendable` are dropped from the restated clause.
    /// Any other inherited protocol must survive, or the mock fails to conform.
    func testActorProtocolRestatesOtherInheritedProtocols() {
        assertMacro {
            """
            @Mockable()
            protocol Session: Actor, Identifiable {
                var id: String { get }
            }
            """
        } expansion: {
            """
            protocol Session: Actor, Identifiable {
                var id: String { get }
            }

            #if DEBUG
            actor MockSession: Identifiable, Session, MockProviding {
                nonisolated let mock = Mock()

                nonisolated func id(_ void: Void = ()) -> Interaction<Void, None, String > {
                    Interaction(.any, spy: self.mock.id)
                }

                nonisolated var id: String {
                    get {
                        Mock.adapt(self.mock.id, ())
                    }
                }
            }
            #endif
            """
        }
    }

    /// Initializers on an actor mock omit `required` (`error: 'required'
    /// initializer in non-class type 'MockSession'`) and chain to no superclass,
    /// since an actor is a root type.
    ///
    /// The synthesized zero-argument `init()` is still emitted. The
    /// conservative test that suppresses it for a composed protocol with a
    /// non-empty inheritance clause does not apply: `: Actor` *is* non-empty,
    /// but an actor can never have a superclass, so the ambiguity that test
    /// guards against cannot arise.
    func testActorProtocolWithInitializerRequirement() {
        assertMacro {
            """
            @Mockable()
            protocol Session: Actor {
                init(value: Int)
            }
            """
        } expansion: {
            """
            protocol Session: Actor {
                init(value: Int)
            }

            #if DEBUG
            actor MockSession: Session, MockProviding {
                nonisolated let mock = Mock()

                static let staticMock = Mock(scopedStorageKey: "MockSession")

                static func `init`(value: ArgMatcher<Int>) -> Interaction<Int, None, Void> {
                    Interaction(value, spy: staticMock.`init`)
                }

                init(value: Int) {
                    let spy: Spy<Int, None, Void> = MockSession.staticMock.`init`
                    Mock.adapt(spy, value)
                }

                init() {
                }
            }
            #endif
            """
        }
    }

    /// `.composition` is redundant for an actor protocol — detection already
    /// forces the composed strategy — and must not change the output.
    func testActorProtocolWithRedundantCompositionOption() {
        assertMacro {
            """
            @Mockable([.composition])
            protocol Session: Actor {
                func ping() -> Bool
            }
            """
        } expansion: {
            """
            protocol Session: Actor {
                func ping() -> Bool
            }

            #if DEBUG
            actor MockSession: Session, MockProviding {
                nonisolated let mock = Mock()

                nonisolated func ping() -> Interaction<Void, None, Bool> {
                    Interaction(.any, spy: self.mock.ping)
                }

                nonisolated func ping() -> Bool {
                    return Mock.adapt(self.mock.ping, ())
                }
            }
            #endif
            """
        }
    }

    /// Naming options compose with actor detection.
    func testActorProtocolWithSuffixMockOption() {
        assertMacro {
            """
            @Mockable([.suffixMock])
            protocol Session: Actor {
                func ping() -> Bool
            }
            """
        } expansion: {
            """
            protocol Session: Actor {
                func ping() -> Bool
            }

            #if DEBUG
            actor SessionMock: Session, MockProviding {
                nonisolated let mock = Mock()

                nonisolated func ping() -> Interaction<Void, None, Bool> {
                    Interaction(.any, spy: self.mock.ping)
                }

                nonisolated func ping() -> Bool {
                    return Mock.adapt(self.mock.ping, ())
                }
            }
            #endif
            """
        }
    }
}
