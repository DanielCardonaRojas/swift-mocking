
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
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

            #if DEBUG
            class MockMyService: @unchecked Sendable, MyService, MockBacked {
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

            #if DEBUG
            class MyServiceMock: @unchecked Sendable, MyService, MockBacked {
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
}
