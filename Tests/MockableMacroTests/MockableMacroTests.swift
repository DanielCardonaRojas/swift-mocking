//
//  MockableMacroTests.swift
//  Mockable
//
//  Created by Daniel Cardona on 6/07/25.
//

import XCTest
import MacroTesting
import MockableMacro
import MockableTypes

final class MockableMacroTests: XCTestCase {
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

            class PricingServiceMock: Mock, DefaultProvider {
                typealias Witness = PricingServiceWitness<PricingServiceMock>
                var defaultProviderRegistry: DefaultProvidableRegistry = .shared
                var instance: Witness.Synthesized {
                    .init(
                        context: self,
                        witness: .init(
                            price: adaptNone(self, super.price)
                        )
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
