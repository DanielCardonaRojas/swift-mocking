
//
//  DefaultProvidableRegistry.swift
//  MockableTypes
//
//  Created by Daniel Cardona on 11/07/25.
//

import Foundation


public protocol DefaultProvider {
    var defaultProviderRegistry: DefaultProvidableRegistry { get set }
}

/// A registry for `DefaultProvidable` types, allowing dynamic control over which types provide default values.
public class DefaultProvidableRegistry {
    /// The shared singleton instance of the registry.
    public static let shared = {
        let registry = DefaultProvidableRegistry()
        registry.register(Array<Any>.self)
        registry.register(Optional<Any>.self)
        registry.register(Set<AnyHashable>.self)
        registry.register(Dictionary<AnyHashable, Any>.self)
        registry.register(Int.self)
        registry.register(Bool.self)
        registry.register(Double.self)
        registry.register(Float.self)
        registry.register(String.self)
        return registry
    }()

    private var registeredTypes: Set<ObjectIdentifier> = []

    public init(_ types: [DefaultProvidable.Type] = []) {
        for type in types {
            registeredTypes.insert(ObjectIdentifier(type))
        }
    }

    public func getDefaultForType<T>(_ type: T.Type) -> T? {
        if type == Void.self {
            return () as? T
        }
        if let providableType = type as? any DefaultProvidable.Type,
           registeredTypes.contains(ObjectIdentifier(providableType)) {
            return providableType.defaultValue as? T
        }
        return nil
    }

    /// Registers a `DefaultProvidable` type with the registry.
    ///
    /// Once registered, `Spy` instances can use the `defaultValue` of this type
    /// if no specific stub is found and the `useDefaultValues` option is enabled.
    /// - Parameter type: The `DefaultProvidable` type to register.
    public func register<T: DefaultProvidable>(_ type: T.Type) {
        registeredTypes.insert(ObjectIdentifier(type))
    }

    public func register(_ types: [DefaultProvidable.Type]) {
        for type in types {
            registeredTypes.insert(ObjectIdentifier(type))
        }
    }

    /// Deregisters a `DefaultProvidable` type from the registry.
    /// - Parameter type: The `DefaultProvidable` type to deregister.
    public func deregister<T: DefaultProvidable>(_ type: T.Type) {
        registeredTypes.remove(ObjectIdentifier(type))
    }

    /// Checks if a `DefaultProvidable` type is registered.
    /// - Parameter type: The `DefaultProvidable` type to check.
    /// - Returns: `true` if the type is registered, `false` otherwise.
    public func isRegistered<T: DefaultProvidable>(_ type: T.Type) -> Bool {
        registeredTypes.contains(ObjectIdentifier(type))
    }
}
