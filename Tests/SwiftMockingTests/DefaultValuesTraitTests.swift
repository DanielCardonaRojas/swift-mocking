//
//  DefaultValuesTraitTests.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 18/10/25.
//

import Testing
import SwiftMocking

@Suite(.withDefaults("Hello"))
struct DefaultValuesTraitTests {
    @Test
    func testInheritsDefaultsFromSuite() async throws {
        let stringSpy = Spy<Void, None, String>()
        let result = stringSpy.call(())

        // Should get the global default (empty string), not custom values from other tests
        #expect(result == "Hello")
    }

    @Test(.withDefaults("Different"))
    func testOverridesInheritedDefault() async throws {
        let stringSpy = Spy<Void, None, String>()
        let result = stringSpy.call(())

        // Should get the global default (empty string), not custom values from other tests
        #expect(result == "Different")
    }

}

@Test(.withDefaults("Custom String", 999, true, [1, 2, 3]))
func testCustomDefaultValues() async throws {
    // Test that custom default values are used for unstubbed methods
    let stringSpy = Spy<Void, None, String>()
    let intSpy = Spy<Void, None, Int>()
    let boolSpy = Spy<Void, None, Bool>()
    let arraySpy = Spy<Void, None, [Int]>()
    let stringResult = stringSpy.call(())
    let intResult = intSpy.call(())
    let boolResult = boolSpy.call(())
    let arrayResult = arraySpy.call(())
    #expect(stringResult == "Custom String")
    #expect(intResult == 999)
    #expect(boolResult == true)
    #expect(arrayResult == [1, 2, 3])
}

@Test
func testIsolationFromDefaultValues() async throws {
    let stringSpy = Spy<Void, None, String>()
    let result = stringSpy.call(())

    // Should get the global default (empty string), not custom values from other tests
    #expect(result == "")
}
