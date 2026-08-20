
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
            class MockService: Mock, @unchecked Sendable, Service {
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
            class MockMyService: Mock, @unchecked Sendable, MyService {
                func value(_ void: Void) -> Interaction<Void, None, Int > {
                    Interaction(.any, spy: super.value)
                }

                    var value: Int {
                    get {
                        adapt(super.value, ())
                    }
                }
            }
            #endif
            """
        }
    }

    func testProtocolWithSettableProperty() {
        assertMacro {
            """
            @Mockable()
            protocol MyService {
                var value: Int { get set }
            }
            """
        } expansion: {
            """
            protocol MyService {
                var value: Int { get set }
            }

            #if DEBUG
            class MockMyService: Mock, @unchecked Sendable, MyService {
                func value(_ void: Void) -> SettableInteraction<Void, None, Int > {
                    SettableInteraction(
                        get: Interaction(.any, spy: super.value),
                        setInteraction: { newValue in
                            Interaction(.any, newValue, spy: super.setValue)
                        }
                    )
                }

                    var value: Int {
                    set {
                        return adapt(super.setValue, (), newValue)
                    }
                    get {
                        adapt(super.value, ())
                    }
                }
            }
            #endif
            """
        }
    }

    /// Setter spy names uppercase only the first character. `String.capitalized`
    /// would lowercase the tail — `setCachepolicy` — which still round-trips at
    /// runtime (both sides agree) but reads as a typo in generated source.
    func testProtocolWithSettableMultiWordProperty() {
        assertMacro {
            """
            @Mockable()
            protocol MyService {
                var cachePolicy: String { get set }
            }
            """
        } expansion: {
            """
            protocol MyService {
                var cachePolicy: String { get set }
            }

            #if DEBUG
            class MockMyService: Mock, @unchecked Sendable, MyService {
                func cachePolicy(_ void: Void) -> SettableInteraction<Void, None, String > {
                    SettableInteraction(
                        get: Interaction(.any, spy: super.cachePolicy),
                        setInteraction: { newValue in
                            Interaction(.any, newValue, spy: super.setCachePolicy)
                        }
                    )
                }

                    var cachePolicy: String {
                    set {
                        return adapt(super.setCachePolicy, (), newValue)
                    }
                    get {
                        adapt(super.cachePolicy, ())
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
            class MockMyService: Mock, @unchecked Sendable, MyService {
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
            class MockMyService: Mock, @unchecked Sendable, MyService {
                subscript(index: ArgMatcher<Int>) -> Interaction<Int, None, String > {
                    get {
                        Interaction(index, spy: super.index)
                    }
                }
                subscript(index: Int) -> String {
                    get {
                        return adapt(super.index, index)
                    }
                }
            }
            #endif
            """
        }
    }

    /// The generic clause must land on every generated declaration — both the
    /// interaction subscript and the conformance subscript — or the expansion
    /// references an undeclared type parameter.
    func testProtocolWithGenericSubscript() {
        assertMacro {
            """
            @Mockable()
            protocol MyService {
                subscript<T: Hashable>(item: T) -> String { get }
            }
            """
        } expansion: {
            """
            protocol MyService {
                subscript<T: Hashable>(item: T) -> String { get }
            }

            #if DEBUG
            class MockMyService: Mock, @unchecked Sendable, MyService {
                subscript <T: Hashable>(item: ArgMatcher<T>) -> Interaction<T, None, String > {
                    get {
                        Interaction(item, spy: super.item)
                    }
                }
                subscript <T: Hashable>(item: T) -> String {
                    get {
                        return adapt(super.item, item)
                    }
                }
            }
            #endif
            """
        }
    }

    func testProtocolWithSettableSubscript() {
        assertMacro {
            """
            @Mockable()
            protocol MyService {
                subscript(index: Int) -> String { get set }
            }
            """
        } expansion: {
            """
            protocol MyService {
                subscript(index: Int) -> String { get set }
            }

            #if DEBUG
            class MockMyService: Mock, @unchecked Sendable, MyService {
                subscript(index: ArgMatcher<Int>) -> SettableInteraction<Int, None, String > {
                    get {
                        SettableInteraction(
                            get: Interaction(index, spy: super.index),
                            setInteraction: { newValue in
                                Interaction(index, newValue, spy: super.setIndex)
                            }
                        )
                    }
                }
                subscript(index: Int) -> String {
                    set {
                        return adapt(super.setIndex, index, newValue)
                    }
                    get {
                        return adapt(super.index, index)
                    }
                }
            }
            #endif
            """
        }
    }

    func testProtocolWithMultiParameterSubscript() {
        assertMacro {
            """
            @Mockable()
            protocol MyService {
                subscript(row: Int, column: Int) -> String { get }
            }
            """
        } expansion: {
            """
            protocol MyService {
                subscript(row: Int, column: Int) -> String { get }
            }

            #if DEBUG
            class MockMyService: Mock, @unchecked Sendable, MyService {
                subscript(row: ArgMatcher<Int>, column: ArgMatcher<Int>) -> Interaction<Int, Int, None, String > {
                    get {
                        Interaction(row, column, spy: super.rowColumn)
                    }
                }
                subscript(row: Int, column: Int) -> String {
                    get {
                        return adapt(super.rowColumn, row, column)
                    }
                }
            }
            #endif
            """
        }
    }

    func testProtocolWithUnlabeledSubscript() {
        assertMacro {
            """
            @Mockable()
            protocol MyService {
                subscript(_ position: Int) -> String { get }
            }
            """
        } expansion: {
            """
            protocol MyService {
                subscript(_ position: Int) -> String { get }
            }

            #if DEBUG
            class MockMyService: Mock, @unchecked Sendable, MyService {
                subscript(_ position: ArgMatcher<Int>) -> Interaction<Int, None, String > {
                    get {
                        Interaction(position, spy: super.position)
                    }
                }
                subscript(_ position: Int) -> String {
                    get {
                        return adapt(super.position, position)
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
            class MockMyService<Item>: Mock, @unchecked Sendable, MyService {
                typealias Item = Item
                func item() -> Interaction<Void, None, Item> {
                    Interaction(.any, spy: super.item)
                }
                func item() -> Item {
                    return adapt(super.item, ())
                }
            }
            #endif
            """
        }
    }
}
