
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
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

            #if DEBUG
            class MockService: Mock, Service {
                func doSomething() -> Interaction<Void, None, Void> {
                    Interaction(.any, spy: super.doSomething)
                }
                func doSomething() {
                    return adapt(super.doSomething)
                }
            }
            #endif
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

            #if DEBUG
            class MockMyService: Mock, MyService {
                func getValue() -> Interaction<Void, None, Int > {
                    Interaction(.any, spy: super.value)
                }

                    var value: Int {
                    get {
                        adapt(super.value)
                    }
                }
            }
            #endif
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

            #if DEBUG
            class MockMyService: Mock, MyService {
                required init(value: Int) {
                }
            }
            #endif
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

            #if DEBUG
            class MockMyService: Mock, MyService {
                subscript(index: ArgMatcher<Int>) -> Interaction<Int, None, String > {
                    get {
                        Interaction(index, spy: super.subscript)
                    }
                }
                subscript(index: Int) -> String {
                    get {
                        return adapt(super.subscript, index)
                    }
                }
            }
            #endif
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

            #if DEBUG
            class MockMyService<Item>: Mock, MyService {
                typealias Item = Item
                func item() -> Interaction<Void, None, Item> {
                    Interaction(.any, spy: super.item)
                }
                func item() -> Item {
                    return adapt(super.item)
                }
            }
            #endif
            """
        }
    }
}
