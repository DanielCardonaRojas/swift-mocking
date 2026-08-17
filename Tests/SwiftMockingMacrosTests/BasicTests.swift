
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import MacroTesting

final class BasicTests: MacroTestCase {
    func testSingleMethodNoEffects() {
        assertMacro {
           """
            @Mockable()
            protocol PricingService {
                func price(_ item: String) -> Int
            }
            """
        } expansion: {
            """
            protocol PricingService {
                func price(_ item: String) -> Int
            }

            #if DEBUG
            class MockPricingService: @unchecked Sendable, PricingService, MockBacked {
                func price(_ item: ArgMatcher<String>) -> Interaction<String, None, Int> {
                    Interaction(item, spy: mock.price)
                }
                func price(_ item: String) -> Int {
                    return mock.adapt(mock.price, item)
                }
                let mock = Mock()
            }
            #endif
            """
        }
    }
}
