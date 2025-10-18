//
//  TestSupportTests.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 18/10/25.
//

import Testing
import SwiftMocking

// Tests run in parallel
struct StaticTests {
    let callCount = 1000
    func staticScope2() async throws {
        let spy: Spy<String, None, Void> = Mock.someMethod
        for _ in 1...callCount {
            spy.call("")
        }
        #expect(spy.invocations.count == callCount)
    }

    func staticScope() async throws {
        let spy: Spy<String, None, Void> = Mock.someMethod
        for _ in 1...1000 {
            spy.call("")
        }
        #expect(spy.invocations.count == callCount)
    }

}
