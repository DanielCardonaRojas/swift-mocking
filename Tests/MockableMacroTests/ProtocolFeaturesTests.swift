
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
                func doSomething() {
                    return adapt(super.doSomething)
                }
                func doSomething() -> Interaction<Void, None, Void> {
                    Interaction(.any, spy: super.doSomething)
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
                func getValue() -> Interaction<Void, None, Int > {
                    Interaction(.any, spy: super.value)
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
                required init(value: Int) {
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

            class MyServiceMock: Mock, MyService {
                subscript(index: Int) -> String {
                    get {
                        return adapt(super.subscript, index)
                    }
                }
                subscript(index: ArgMatcher<Int>) -> Interaction<Int, None, String > {
                    get {
                        Interaction(index, spy: super.subscript)
                    }
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

            class MyServiceMock<Item>: Mock, MyService {
                typealias Item = Item
                func item() -> Item {
                    return adapt(super.item)
                }
                func item() -> Interaction<Void, None, Item> {
                    Interaction(.any, spy: super.item)
                }
            }
            """
        }
    }
}
