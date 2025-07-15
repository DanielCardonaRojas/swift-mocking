
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import MockableMacro
import MacroTesting

final class MacroOptionsTests: XCTestCase {
    override func invokeTest() {
      withMacroTesting(
        record: false,
        macros: ["Mockable": MockableMacro.self]
      ) {
        super.invokeTest()
      }
    }

    func testPrefixMockOption() {
        assertMacro {
            """
            @Mockable([.prefixMock])
            protocol MyService {
                func doSomething()
            }
            """
        } expansion: {
            #"""
            protocol MyService {
                func doSomething()
            }

            class MockMyService: Mock, DefaultProvider {
                typealias Witness = MyServiceWitness<MockMyService>
                var defaultProviderRegistry: DefaultProvidableRegistry = .shared
                var instance: Witness.Synthesized {
                    .init(context: self, witness: .init(doSomething: adapt(\.doSomething_)))
                }
                let doSomething_ = Spy<None, Void>()
                func doSomething() -> Interaction<None, Void> {
                    Interaction(spy: super.doSomething_)
                }
            }
            """#
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
            #"""
            protocol MyService {
                func doSomething()
            }

            class MyServiceMock: Mock, DefaultProvider {
                typealias Witness = MyServiceWitness<MyServiceMock>
                var defaultProviderRegistry: DefaultProvidableRegistry = .shared
                var instance: Witness.Synthesized {
                    .init(context: self, witness: .init(doSomething: adapt(\.doSomething_)))
                }
                let doSomething_ = Spy<None, Void>()
                func doSomething() -> Interaction<None, Void> {
                    Interaction(spy: super.doSomething_)
                }
            }
            """#
        }
    }
}
