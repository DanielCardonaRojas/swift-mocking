//
//  AnySpy.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 8/10/25.
//

/// A type-erased protocol that defines the common interface for all spy objects.
///
/// This protocol provides a unified interface for managing spy objects regardless
/// of their specific type parameters. It allows the `Mock` class to store and
/// manage spies with different signatures in a collection.
///
/// The protocol defines essential properties and methods that all spies must support:
/// - Tracking the number of invocations
/// - Managing logging configuration
/// - Providing default value registries
/// - Clearing recorded state
protocol AnySpy: AnyObject {
    /// The registry used to provide default values for unstubbed method calls.
    var defaultProviderRegistry: DefaultProvidableRegistry? { get set }

    /// The total number of times this spy has been invoked.
    var invocationCount: Int { get }

    /// Whether logging is enabled for this spy's invocations.
    var isLoggingEnabled: Bool { get set }

    /// Clears all recorded invocations and stubs from this spy.
    func clear()
}

