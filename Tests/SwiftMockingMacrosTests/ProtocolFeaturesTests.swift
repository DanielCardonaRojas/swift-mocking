
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
            class MockService: @unchecked Sendable, Service, MockBacked {
                func doSomething() -> Interaction<Void, None, Void> {
                    Interaction(.any, spy: mock.doSomething)
                }
                func doSomething() {
                    return mock.adapt(mock.doSomething)
                }
                let mock = Mock()
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
            class MockMyService: @unchecked Sendable, MyService, MockBacked {
                func getValue() -> Interaction<Void, None, Int > {
                    Interaction(.any, spy: mock.value)
                }

                    var value: Int {
                    get {
                        mock.adapt(mock.value)
                    }
                }
                let mock = Mock()
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
            class MockMyService: @unchecked Sendable, MyService, MockBacked {
                required init(value: Int) {
                }
                let mock = Mock()
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
            class MockMyService: @unchecked Sendable, MyService, MockBacked {
                subscript(index: ArgMatcher<Int>) -> Interaction<Int, None, String > {
                    get {
                        Interaction(index, spy: mock.subscript)
                    }
                }
                subscript(index: Int) -> String {
                    get {
                        return mock.adapt(mock.subscript, index)
                    }
                }
                let mock = Mock()
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
            class MockMyService<Item>: @unchecked Sendable, MyService, MockBacked {
                typealias Item = Item
                func item() -> Interaction<Void, None, Item> {
                    Interaction(.any, spy: mock.item)
                }
                func item() -> Item {
                    return mock.adapt(mock.item)
                }
                let mock = Mock()
            }
            #endif
            """
        }
    }
}
