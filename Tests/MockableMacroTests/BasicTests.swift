
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import MockableMacro
import MacroTesting

final class BasicTests: XCTestCase {
    override func invokeTest() {
      withMacroTesting(
        record: false,
        macros: ["Mockable": MockableMacro.self]
      ) {
        super.invokeTest()
      }
    }

    func testSingleMethodNoEffects() {
        assertMacro {
           """
            @Mockable()
            protocol PricingService {
                func price(_ item: String) -> Int
            }
            """
        } expansion: {
            #"""
            protocol PricingService {
                func price(_ item: String) -> Int
            }

            struct PricingServiceMock {
                typealias Witness = PricingServiceWitness<Self>
                var instance: Witness.Synthesized {
                    .init(context: self, witness: .init(price: adapt(\.price)))
                }
                let price = Spy<String, None, Int>()
                func price(_ item: ArgMatcher<String>) -> Interaction<String, None, Int> {
                    Interaction(item, spy: price)
                }
            }
            """#
        }
    }
}
