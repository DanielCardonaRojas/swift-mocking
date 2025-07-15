
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
            """
            public protocol Service {
                func doSomething()
            }

            class ServiceMock: Mock, DefaultProvider {
                typealias Witness = ServiceWitness<ServiceMock>
                var defaultProviderRegistry: DefaultProvidableRegistry = .shared
                var instance: Witness.Synthesized {
                    .init(
                        context: self,
                        witness: .init(
                            doSomething: adaptNone(self, super.doSomething)
                        )
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

            class MyServiceMock: Mock, DefaultProvider {
                typealias Witness = MyServiceWitness<MyServiceMock>
                var defaultProviderRegistry: DefaultProvidableRegistry = .shared
                var instance: Witness.Synthesized {
                    .init(
                        context: self,
                        witness: .init(
                        )
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

            class MyServiceMock: Mock, DefaultProvider {
                typealias Witness = MyServiceWitness<MyServiceMock>
                var defaultProviderRegistry: DefaultProvidableRegistry = .shared
                var instance: Witness.Synthesized {
                    .init(
                        context: self,
                        witness: .init(
                        )
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

            class MyServiceMock: Mock, DefaultProvider {
                typealias Witness = MyServiceWitness<MyServiceMock>
                var defaultProviderRegistry: DefaultProvidableRegistry = .shared
                var instance: Witness.Synthesized {
                    .init(
                        context: self,
                        witness: .init(
                        )
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

            class MyServiceMock: Mock, DefaultProvider {
                typealias Witness = MyServiceWitness<MyServiceMock>
                var defaultProviderRegistry: DefaultProvidableRegistry = .shared
                var instance: Witness.Synthesized {
                    .init(
                        context: self,
                        witness: .init(
                            item: adaptNone(self, super.item)
                        )
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
