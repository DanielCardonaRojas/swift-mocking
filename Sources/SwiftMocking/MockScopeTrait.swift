//
//  MockScopeTrait.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 18/10/25.
//

import Testing

#if swift(>=6.1)
/// A swift-testing trait that provides isolated mock scope and invocation recording.
///
/// Use this trait to ensure static spies and invocation recordings remain isolated
/// across concurrently running tests in swift-testing.
///
/// Example:
/// ```swift
/// @Test(.mocking)
/// func testExample() async throws {
///     // Test code with isolated mocks
/// }
/// ```
public struct MockScopeTrait: TestTrait, TestScoping {
  public func provideScope(
    for test: Test,
    testCase: Test.Case?,
    performing function: @Sendable () async throws -> Void
  ) async throws {
      try await MockScope.withStorage {
          try await MockScope.withInvocationRecorder {
              try await function()
          }
      }
  }
}

public extension Trait where Self == MockScopeTrait {
    static var mocking: Self {
        Self()
    }
}
#endif
