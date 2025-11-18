//
//  TestSupportTests.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 18/10/25.
//

import Testing
import SwiftMocking

#if swift(>=6.1)
// Tests run in parallel
struct StaticTests {
    let callCount = 1000
    @Test(.mocking)
    func staticScope2() async throws {
        let spy: Spy<String, None, Void> = Mock.someMethod
        for _ in 1...callCount {
            spy("")
        }
        #expect(spy.invocations.count == callCount)
    }

    @Test(.mocking)
    func staticScope() async throws {
        let spy: Spy<String, None, Void> = Mock.someMethod
        for _ in 1...1000 {
            spy("")
        }
        #expect(spy.invocations.count == callCount)
    }

}
#endif
