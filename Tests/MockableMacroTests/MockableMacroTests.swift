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

final class MockableMacroTests: MacroTestCase {
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

            class PricingServiceMock: Mocking {
                typealias Witness = PricingServiceWitness<PricingServiceMock>
                typealias Conformance = Witness.Synthesized
                required override init() {
                    super.init()
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
