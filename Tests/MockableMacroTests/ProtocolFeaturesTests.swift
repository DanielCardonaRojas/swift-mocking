
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import MockableMacro
import MacroTesting

final class ProtocolFeaturesTests: XCTestCase {
    override func invokeTest() {
      withMacroTesting(
        record: false,
        macros: ["Mockable": MockableMacro.self]
      ) {
        super.invokeTest()
      }
    }

    func testPublicProtocol() {
        assertMacro {
           """
            @Mockable()
            public protocol Service {
                func doSomething()
            }
            """
        } expansion: {
            #"""
            public protocol Service {
                func doSomething()
            }

            struct ServiceMock {
                typealias Witness = ServiceWitness<Self>
                var instance: Witness.Synthesized {
                    .init(context: self, witness: .init(doSomething: adapt(\.doSomething_)))
                }
                let doSomething_ = Spy<None, Void>()
                func doSomething() -> Interaction<None, Void> {
                    Interaction(spy: doSomething_)
                }
            }
            """#
        }
    }

    func testProtocolWithProperty() {
        assertMacro {
            """
            @Mockable()
            protocol MyService {
                var value: Int { get }
            }
            """
        } expansion: {
            """
            protocol MyService {
                var value: Int { get }
            }

            struct MyServiceMock {
                typealias Witness = MyServiceWitness<Self>
                var instance: Witness.Synthesized {
                    .init(context: self, witness: .init())
                }
            }
            """
        }
    }

    func testProtocolWithInitializer() {
        assertMacro {
            """
            @Mockable()
            protocol MyService {
                init(value: Int)
            }
            """
        } expansion: {
            """
            protocol MyService {
                init(value: Int)
            }

            struct MyServiceMock {
                typealias Witness = MyServiceWitness<Self>
                var instance: Witness.Synthesized {
                    .init(context: self, witness: .init())
                }
            }
            """
        }
    }

    func testProtocolWithSubscript() {
        assertMacro {
            """
            @Mockable()
            protocol MyService {
                subscript(index: Int) -> String { get }
            }
            """
        } expansion: {
            """
            protocol MyService {
                subscript(index: Int) -> String { get }
            }

            struct MyServiceMock {
                typealias Witness = MyServiceWitness<Self>
                var instance: Witness.Synthesized {
                    .init(context: self, witness: .init())
                }
            }
            """
        }
    }

    func testProtocolWithAssociatedType() {
        assertMacro {
            """
            @Mockable()
            protocol MyService {
                associatedtype Item
                func item() -> Item
            }
            """
        } expansion: {
            #"""
            protocol MyService {
                associatedtype Item
                func item() -> Item
            }

            struct MyServiceMock {
                typealias Witness = MyServiceWitness<Self>
                var instance: Witness.Synthesized {
                    .init(context: self, witness: .init(item: adapt(\.item_)))
                }
                let item_ = Spy<None, Item>()
                func item() -> Interaction<None, Item> {
                    Interaction(spy: item_)
                }
            }
            """#
        }
    }
}
