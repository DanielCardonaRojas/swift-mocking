
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import MockableMacro
import MacroTesting

final class MacroOptionsTests: MacroTestCase {
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

            class MockMyService: Mocking {
                typealias Witness = MyServiceWitness<MockMyService>
                typealias Conformance = MyServiceWitness<MockMyService>.Synthesized
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

            class MyServiceMock: Mocking {
                typealias Witness = MyServiceWitness<MyServiceMock>
                typealias Conformance = MyServiceWitness<MyServiceMock>.Synthesized
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
}
