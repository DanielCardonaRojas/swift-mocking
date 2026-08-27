
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
                func value(_ void: Void = ()) -> Interaction<Void, None, Int > {
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
                func value(_ void: Void = ()) -> SettableInteraction<Void, None, Int > {
                    SettableInteraction(
                        get: Interaction(.any, spy: super.value),
                        setInteraction: { newValue in
                            let writeSpy: Spy<Void, Int, None, Void> = super.setValue
                            let writeInteraction: Interaction<Void, Int, None, Void> = Interaction(.any, newValue, spy: writeSpy)
                            return writeInteraction
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
                func cachePolicy(_ void: Void = ()) -> SettableInteraction<Void, None, String > {
                    SettableInteraction(
                        get: Interaction(.any, spy: super.cachePolicy),
                        setInteraction: { newValue in
                            let writeSpy: Spy<Void, String, None, Void> = super.setCachePolicy
                            let writeInteraction: Interaction<Void, String, None, Void> = Interaction(.any, newValue, spy: writeSpy)
                            return writeInteraction
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
                        Interaction(index, spy: super.subscriptIndex)
                    }
                }

                subscript(index: Int) -> String {
                    get {
                        return adapt(super.subscriptIndex, index)
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
                            get: Interaction(index, spy: super.subscriptIndex),
                            setInteraction: { newValue in
                                let writeSpy: Spy<Int, String, None, Void> = super.setSubscriptIndex
                                let writeInteraction: Interaction<Int, String, None, Void> = Interaction(index, newValue, spy: writeSpy)
                                return writeInteraction
                            }
                        )
                    }
                }

                subscript(index: Int) -> String {
                    set {
                        return adapt(super.setSubscriptIndex, index, newValue)
                    }
                    get {
                        return adapt(super.subscriptIndex, index)
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
                        Interaction(item, spy: super.subscriptItem)
                    }
                }

                subscript <T: Hashable>(item: T) -> String {
                    get {
                        return adapt(super.subscriptItem, item)
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
                        Interaction(row, column, spy: super.subscriptRowColumn)
                    }
                }

                subscript(row: Int, column: Int) -> String {
                    get {
                        return adapt(super.subscriptRowColumn, row, column)
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
                        Interaction(position, spy: super.subscriptPosition)
                    }
                }

                subscript(_ position: Int) -> String {
                    get {
                        return adapt(super.subscriptPosition, position)
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

    /// `mutating` is valid on a protocol requirement but not on a class member,
    /// so the generated mock must not carry it — `'mutating' is not valid on
    /// instance methods in classes`. A class conforms by omitting the modifier.
    func testMutatingRequirementDropsModifier() {
        assertMacro {
            """
            @Mockable()
            protocol Repository {
                mutating func save(_ value: String)
            }
            """
        } expansion: {
            """
            protocol Repository {
                mutating func save(_ value: String)
            }

            #if DEBUG
            class MockRepository: Mock, @unchecked Sendable, Repository {
                func save(_ value: ArgMatcher<String>) -> Interaction<String, None, Void> {
                    Interaction(value, spy: super.save)
                }

                func save(_ value: String) {
                    return adapt(super.save, value)
                }
            }
            #endif
            """
        }
    }

    /// `static` must survive the same filtering that removes `mutating`.
    func testMutatingAndStaticRequirementsKeepStatic() {
        assertMacro {
            """
            @Mockable()
            protocol Repository {
                mutating func save(_ value: String)
                static func reset()
            }
            """
        } expansion: {
            """
            protocol Repository {
                mutating func save(_ value: String)
                static func reset()
            }

            #if DEBUG
            class MockRepository: Mock, @unchecked Sendable, Repository {
                func save(_ value: ArgMatcher<String>) -> Interaction<String, None, Void> {
                    Interaction(value, spy: super.save)
                }

                static func reset() -> Interaction<Void, None, Void> {
                    Interaction(.any, spy: super.reset)
                }

                func save(_ value: String) {
                    return adapt(super.save, value)
                }

                static func reset() {
                    return adapt(super.reset, ())
                }
            }
            #endif
            """
        }
    }
}
