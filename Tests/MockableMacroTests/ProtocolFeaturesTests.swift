
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

            class ServiceMock: Mocking {
                typealias Witness = ServiceWitness<ServiceMock>
                typealias Conformance = Witness.Synthesized
                required override init() {
                    super.init()
                    self.setup()
                }
                lazy var instance: Conformance = .init(context: self, strategy: "mocking")
                var witness: Witness {
                    .init(
                        doSomething: adaptNone(self, super.doSomething)
                    )
                }
                func doSomething() -> Interaction<None, Void> {
                    Interaction(spy: super.doSomething)
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

            class MyServiceMock: Mocking {
                typealias Witness = MyServiceWitness<MyServiceMock>
                typealias Conformance = Witness.Synthesized
                required override init() {
                    super.init()
                    self.setup()
                }
                lazy var instance: Conformance = .init(context: self, strategy: "mocking")
                var witness: Witness {
                    .init(
                    )
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

            class MyServiceMock: Mocking {
                typealias Witness = MyServiceWitness<MyServiceMock>
                typealias Conformance = Witness.Synthesized
                required override init() {
                    super.init()
                    self.setup()
                }
                lazy var instance: Conformance = .init(context: self, strategy: "mocking")
                var witness: Witness {
                    .init(
                    )
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

            class MyServiceMock: Mocking {
                typealias Witness = MyServiceWitness<MyServiceMock>
                typealias Conformance = Witness.Synthesized
                required override init() {
                    super.init()
                    self.setup()
                }
                lazy var instance: Conformance = .init(context: self, strategy: "mocking")
                var witness: Witness {
                    .init(
                    )
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

            class MyServiceMock: Mocking {
                typealias Witness = MyServiceWitness<MyServiceMock>
                typealias Conformance = Witness.Synthesized
                required override init() {
                    super.init()
                    self.setup()
                }
                lazy var instance: Conformance = .init(context: self, strategy: "mocking")
                var witness: Witness {
                    .init(
                        item: adaptNone(self, super.item)
                    )
                }
                func item() -> Interaction<None, Item> {
                    Interaction(spy: super.item)
                }
            }
            """
        }
    }
}
