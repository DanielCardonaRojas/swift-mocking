
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
            """
            protocol MyService {
                func doSomething()
            }

            class MockMyService: Mock {
                typealias Witness = MyServiceWitness<MockMyService>
                var instance: Witness.Synthesized {
                    witness.register(strategy: "mocking")
                    return .init(context: self, strategy: "mocking")
                }
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

    func testSuffixMockOption() {
        assertMacro {
            """
            @Mockable([.suffixMock])
            protocol MyService {
                func doSomething()
            }
            """
        } expansion: {
            """
            protocol MyService {
                func doSomething()
            }

            class MyServiceMock: Mock {
                typealias Witness = MyServiceWitness<MyServiceMock>
                var instance: Witness.Synthesized {
                    witness.register(strategy: "mocking")
                    return .init(context: self, strategy: "mocking")
                }
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
}
