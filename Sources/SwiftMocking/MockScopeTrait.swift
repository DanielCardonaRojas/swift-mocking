//
//  MockScopeTrait.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 18/10/25.
//

import Testing

public struct MockScopeTrait: TestTrait, TestScoping {
  public func provideScope(
    for test: Test,
    testCase: Test.Case?,
    performing function: @Sendable () async throws -> Void
  ) async throws {
      try await MockScope.withStorage {
      try await function()
    }
  }
}

public extension Trait where Self == MockScopeTrait {
    static var mocking: Self {
        Self()
    }
}
