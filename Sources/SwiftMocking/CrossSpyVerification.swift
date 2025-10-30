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
    var methodLabel: String { get }

    /// Checks if a recorded invocation matches this verification criterion
    /// - Parameter recorded: The recorded invocation to match against
    /// - Returns: true if the recorded invocation matches this verification
    func matches(_ recorded: Recorded) -> Bool
}

/// A cross-spy verification descriptor that wraps an existing Interaction
///
/// This allows existing Interaction objects to participate in cross-spy verification
/// while maintaining backward compatibility.
public struct CrossSpyInteraction<each Input, Eff: Effect, Output>: CrossSpyVerifiable {
    private let interaction: Interaction<repeat each Input, Eff, Output>

    public var spyID: UUID {
        interaction.spy.spyID
    }

    public var methodLabel: String {
        interaction.spy.methodLabel ?? ""
    }

    public init(_ interaction: Interaction<repeat each Input, Eff, Output>) {
        self.interaction = interaction
    }

    public func matches(_ recorded: Recorded) -> Bool {
        // Check spy ID first for efficiency
        guard recorded.spyID == spyID else { return false }

        // Check method label match
        guard recorded.methodLabel == methodLabel else { return false }

        // For now, we'll use a simpler approach that just checks spy and method match
        // A more sophisticated implementation would check argument matchers
        // but that requires deeper integration with the type system
        return true
    }
}

/// Verification engine that processes cross-spy call order verification
public enum CrossSpyVerificationEngine {

    /// Verifies that a sequence of cross-spy interactions occurred in the specified order
    /// - Parameter verifiables: Array of verification descriptors in expected order
    /// - Returns: true if all interactions occurred in the specified order
    public static func verifyInOrder(_ verifiables: [any CrossSpyVerifiable]) -> [Recorded]? {
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

        return recordings
    }
}

// Extension to make Interaction conform to CrossSpyVerifiable
extension Interaction: CrossSpyVerifiable {
    public var spyID: UUID {
        spy.spyID
    }

    public var methodLabel: String {
        spy.methodLabel ?? ""
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
