
//
//  DefaultProvidableRegistry.swift
//  MockableTypes
//
//  Created by Daniel Cardona on 11/07/25.
//

import Foundation


/// A type that owns a `DefaultProvidableRegistry`.
///
/// This protocol is typically adopted by mock objects that need to provide default values
/// for properties or return types of methods that haven't been explicitly stubbed.
public protocol DefaultProvider {
    /// The registry used to look up and provide default values for various types.
    var defaultProviderRegistry: DefaultProvidableRegistry { get set }
}

/// A registry for `DefaultProviding` types, allowing dynamic control over which types provide default values.
///
/// This registry holds a collection of `DefaultProviding` instances, each capable of generating
/// a default value for a specific type. It is used by the mocking framework to supply
/// sensible default return values when a mock's behavior is not explicitly defined.
public struct DefaultProvidableRegistry: @unchecked Sendable {
    /// The shared, default instance of `DefaultProvidableRegistry`.
    ///
    /// This instance is pre-populated with common default providers for types like `Void`,
    /// `Array`, `Optional`, `Set`, `Dictionary`, `Bool`, `String`, `Int`, `Double`, and `Float`.
    public static let `default`: DefaultProvidableRegistry = {
        var instance = DefaultProvidableRegistry()
        instance.register(.void())
        instance.register(.array())
        instance.register(.optional())
        instance.register(.set())
        instance.register(.dictionary())
        instance.register(.bool())
        instance.register(.string())
        instance.register(.numeric(Int.self))
        instance.register(.numeric(Double.self))
        instance.register(.numeric(Float.self))
        return instance
    }()


    /// The internal storage for the registered `DefaultProviding` instances.
    var providers: [String : DefaultProviding] = [:]

    /// Creates a new, empty `DefaultProvidableRegistry`.
    public init() { }

    /// Retrieves a default value for a given type `T` from the registered providers.
    ///
    /// The registry iterates through its `DefaultProviding` instances in the order they were registered.
    /// The first provider that can create a default value of the requested type `T` will be used.
    ///
    /// - Parameter type: The type for which a default value is requested.
    /// - Returns: An optional default value of type `T`, or `nil` if no suitable provider is found.
    public func getDefaultForType<T>(_ type: T.Type) -> T? {
        let parsed = MetatypeParser.parse(T.self)
        guard let provider = providers[parsed.name] else {
            return nil
        }

        if let defaultValue = provider.createDefault() as? T {
            return defaultValue
        }

        return nil
    }

    /// Registers a `DefaultProviding` instance with the registry.
    ///
    /// When a default value is requested for a type, the registry will consult its registered
    /// providers in the order they were added. If multiple providers can supply a default
    /// for the same type, the one registered first will be used.
    ///
    /// - Parameter providing: The `DefaultProviding` instance to register.
    public mutating func register(_ providing: DefaultProviding) {
        providers[providing.defaultType.name] = providing
    }

    /// Deregisters a `DefaultProviding` instance from the registry.
    ///
    /// This removes all providers that match the `defaultType` of the provided `DefaultProviding` instance.
    ///
    /// - Parameter providing: The `DefaultProviding` instance to deregister.
    public mutating func deregister(_ providing: DefaultProviding) {
        providers.removeValue(forKey: providing.defaultType.name)
    }
}
