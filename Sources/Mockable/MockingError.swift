//
//  MockingError.swift
//  Mockable
//
//  Created by Daniel Cardona on 4/07/25.
//

public struct MockingError: Error {
    public let message: String

    public static let unStubbed = MockingError(message: "Unstubbed method")
    public static let didNotThrow = MockingError(message: "Did not find any invocation that throws")
    public static func didNotMatchThrown(_ thrown: [any Error]) -> MockingError {
        return MockingError(message: "Did not match any thrown error. Thrown: \(thrown)")
    }
    public static func unfulfilledCallCount(_ actual: Int) -> MockingError {
        MockingError(message: "Unfulfilled call count. Actual: \(actual)")
    }
}
