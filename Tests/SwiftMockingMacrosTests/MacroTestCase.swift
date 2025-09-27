//
//  MacroTestCase.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 17/07/25.
//
import XCTest
import MacroTesting
import SwiftMockingMacros

class  MacroTestCase: XCTestCase {
    override func invokeTest() {
      withMacroTesting(
        record: false,
        macros: ["Mockable": MockableMacro.self]
      ) {
        super.invokeTest()
      }
    }

}

