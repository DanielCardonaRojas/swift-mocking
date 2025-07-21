
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import MockableMacro
import MacroTesting

final class ProtocolFeaturesTests: MacroTestCase {

    func testPublicProtocol() {
        assertMacro {
           """
            @Mockable()
            public protocol Service {
                func doSomething()
            }
            """
        } expansion: {
            """
            public protocol Service {
                func doSomething()
            }

            class ServiceMock: Mock, Service {
                func doSomething() -> Interaction<None, Void> {
                    Interaction(spy: super.doSomething)
                }
                func doSomething() {
                    return adapt(super.doSomething)
                }
            }
            """
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

            class MyServiceMock: Mock, MyService {
                var value: Int {
                    get {
                        adapt(super.value)
                    }
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

            class MyServiceMock: Mock, MyService {
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

            class MyServiceMock: Mock, MyService {
                subscript(index: Int) -> String {
                    get
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
            """
            protocol MyService {
                associatedtype Item
                func item() -> Item
            }

            class MyServiceMock: Mock, MyService {
                func item() -> Interaction<None, Item> {
                    Interaction(spy: super.item)
                }
                func item() -> Item {
                    return adapt(super.item)
                }
            }
            """
        }
    }
}
