
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

    /// A protocol with static requirements gets a second `Mock` for them:
    /// static members cannot reach an instance property. The mock also conforms
    /// to `StaticMockProviding`, which is what supplies its static `clear()`.
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
            class MockMyService: SampleBase, MyService, MockProviding, StaticMockProviding, @unchecked Sendable {
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
    /// initializer must chain to `super.init`. The macro never sees that
    /// superclass and so cannot synthesize the call — `fatalError` satisfies
    /// the rule without naming an initializer. The inheriting strategy keeps an
    /// empty body, since `Mock` always has a zero-argument initializer.
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

                required init(value: Int) {
                    fatalError("init(...) is not implemented on generated mocks")
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
