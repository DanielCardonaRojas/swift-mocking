//
//  InvocationRecorder.swift
//  swift-mocking
//
//  Created by Daniel Cardona
//

import Foundation

/// Metadata representing a single recorded invocation across the global timeline.
///
/// This lightweight struct captures essential information about method calls across all spies,
/// enabling cross-spy call order verification while maintaining performance.
public struct Recorded: Sendable {
    /// Sequential index in the global timeline
    public let index: Int

    /// Unique identifier for the spy instance that recorded this invocation
    public let spyID: UUID

    /// Unique identifier for this specific invocation within the spy
    public let invocationID: UUID

    /// Human-readable method label for debugging and matching
    public let methodLabel: String

    /// Timestamp when the invocation was recorded
    public let timestamp: Date

    /// Type-erased arguments for cross-spy matching
    public let arguments: [Any]

    internal init(
        index: Int,
        spyID: UUID,
        invocationID: UUID,
        methodLabel: String,
        arguments: [Any]
    ) {
        self.index = index
        self.spyID = spyID
        self.invocationID = invocationID
        self.methodLabel = methodLabel
        self.timestamp = Date()
        self.arguments = arguments
    }
}

/// A thread-safe global recorder that captures invocations across all spies for cross-spy verification.
///
/// The InvocationRecorder maintains a chronological timeline of all method calls across different
/// mock objects, enabling verification of call order between multiple spies while preserving
/// type safety within individual spies.
@globalActor
public actor InvocationRecorder {
    public static let shared = InvocationRecorder()

    private var recordings: [Recorded] = []
    private var nextIndex: Int = 0
    private let lock = NSLock()

    private init() {}

    /// Records a new invocation in the global timeline.
    ///
    /// - Parameters:
    ///   - spyID: Unique identifier of the spy recording the invocation
    ///   - invocationID: Unique identifier for this specific invocation
    ///   - methodLabel: Human-readable method label for debugging
    ///   - arguments: Type-erased arguments for matching
    /// - Returns: The recorded invocation metadata
    @discardableResult
    public func record(
        spyID: UUID,
        invocationID: UUID,
        methodLabel: String,
        arguments: [Any]
    ) -> Recorded {
        lock.lock()
        defer { lock.unlock() }

        let recorded = Recorded(
            index: nextIndex,
            spyID: spyID,
            invocationID: invocationID,
            methodLabel: methodLabel,
            arguments: arguments
        )

        recordings.append(recorded)
        nextIndex += 1

        return recorded
    }

    /// Returns an immutable snapshot of all recorded invocations.
    ///
    /// - Returns: Array of all recorded invocations in chronological order
    public func snapshot() -> [Recorded] {
        lock.lock()
        defer { lock.unlock() }
        return Array(recordings)
    }

    /// Clears all recorded invocations.
    ///
    /// This should be called between tests to ensure clean state.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        recordings.removeAll()
        nextIndex = 0
    }

    /// Returns the total number of recorded invocations.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return recordings.count
    }
}
