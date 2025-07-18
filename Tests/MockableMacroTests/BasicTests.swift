
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
            """
            protocol PricingService {
                func price(_ item: String) -> Int
            }

            class PricingServiceMock: Mock, MockWitnessContainer {
                typealias Witness = PricingServiceWitness<PricingServiceMock>
                typealias Conformance = PricingServiceWitness<PricingServiceMock>.Synthesized
                required override init() {super.init()
                    self.setup()
                }
                lazy var instance: Conformance = .init(context: self, strategy: "mocking")
                var witness: Witness {
                    .init(
                        price: adaptNone(self, super.price)
                    )
                }
                func price(_ item: ArgMatcher<String>) -> Interaction<String, None, Int> {
                    Interaction(item, spy: super.price)
                }
            }
            """
        }
    }
}
