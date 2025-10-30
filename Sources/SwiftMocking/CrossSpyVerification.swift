//
//  CrossSpyVerification.swift
//  swift-mocking
//
//  Created by Daniel Cardona
//

import Foundation

/// A protocol that enables cross-spy verification for interactions.
///
/// Types conforming to this protocol can be used in `verifyInOrder` calls
/// that span multiple spies and mock objects.
public protocol CrossSpyVerifiable {
    /// The unique identifier of the spy that recorded this interaction
    var spyID: UUID { get }

    /// The method label for matching recorded invocations
    var methodLabel: String? { get }

    /// Checks if a recorded invocation matches this verification criterion
    /// - Parameter recorded: The recorded invocation to match against
    /// - Returns: true if the recorded invocation matches this verification
    func matches(_ recorded: Recorded) -> Bool
}

/// Verification engine that processes cross-spy call order verification
public enum CrossSpyVerification {

    /// Result of a partial verification failure, containing matched interactions and remaining expected count
    public struct Result {
        /// The interactions that were successfully matched in order
        public let matched: [Recorded]

        /// The number of expected interactions that were not found
        public let expectedRemaining: Int
    }

    /// Verifies that a sequence of cross-spy interactions occurred in the specified order
    /// - Parameter verifiables: Array of verification descriptors in expected order
    /// - Returns: nil if all interactions occurred in the specified order, or a Result containing matched interactions and remaining expected count on partial match
    public static func verifyInOrder(_ verifiables: [any CrossSpyVerifiable]) -> Result? {
        guard !verifiables.isEmpty else { return nil }

        // Get snapshot synchronously using a blocking call
        var recordings: [Recorded] = []
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            recordings = await InvocationRecorder.shared.snapshot()
            semaphore.signal()
        }

        semaphore.wait()

        var verificationIndex = 0
        var lastMatchedIndex = -1

        for recorded in recordings {
            // If we've verified all interactions, we're done
            if verificationIndex >= verifiables.count {
                break
            }

            let currentVerification = verifiables[verificationIndex]

            // Check if this recorded invocation matches our current verification
            if currentVerification.matches(recorded) {
                // Ensure this comes after the previous match
                if recorded.index > lastMatchedIndex {
                    lastMatchedIndex = recorded.index
                    verificationIndex += 1
                }
            }
        }

        // Success if we verified all interactions
        if verificationIndex == verifiables.count {
            return nil
        }

        // Partial match: return matched recordings and remaining expected count
        let matched = Array(recordings.prefix(lastMatchedIndex + 1))
        let expectedRemaining = verifiables.count - verificationIndex
        return Result(matched: matched, expectedRemaining: expectedRemaining)
    }
}

// Extension to make Interaction conform to CrossSpyVerifiable
extension Interaction: CrossSpyVerifiable {
    public var spyID: UUID {
        spy.spyID
    }

    public var methodLabel: String? {
        spy.methodLabel
    }

    public func matches(_ recorded: Recorded) -> Bool {
        // Check spy ID first for efficiency
        guard recorded.spyID == spyID else { return false }

        // Check method label match
        guard recorded.methodLabel == methodLabel else { return false }

        // Grab the invocation by id
        guard let invocation = spy.invocations.first(
            where: { $0.invocationID == recorded.invocationID
            }) else {
            return false
        }

        // Attempt to match invocation with that of the interaction
        return invocationMatcher.isMatchedBy(invocation)
    }
}
