
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

            class MockMyService: Mock, MyService {
                func doSomething() -> Interaction<None, Void> {
                    Interaction(spy: super.doSomething)
                }
                func doSomething() {
                    return adapt(super.doSomething)
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

            class MyServiceMock: Mock, MyService {
                func doSomething() -> Interaction<None, Void> {
                    Interaction(spy: super.doSomething)
                }
                func doSomething() {
                    return adapt(super.doSomething)
                }
            }
            """
        }
    }
}
