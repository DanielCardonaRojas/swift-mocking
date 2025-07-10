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
        }
    }

}
