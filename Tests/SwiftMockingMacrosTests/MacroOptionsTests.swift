
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
}
