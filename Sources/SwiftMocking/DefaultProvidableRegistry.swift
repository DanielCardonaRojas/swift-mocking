
//
//  DefaultProvidableRegistry.swift
//  MockableTypes
//
//  Created by Daniel Cardona on 11/07/25.
//

import Foundation


/// A type that owns a `DefaultProvidableRegistry`
public protocol DefaultProvider {
    var defaultProviderRegistry: DefaultProvidableRegistry { get set }
}

/// A registry for `DefaultProvidable` types, allowing dynamic control over which types provide default values.
public class DefaultProvidableRegistry {
    public static let shared: DefaultProvidableRegistry = {
        let instance = DefaultProvidableRegistry()
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


    var providers: [AnyDefaultProviding] = []
    
    public init() { }

    public func getDefaultForType<T>(_ type: T.Type) -> T? {
        for provider in providers {
            if let defaultValue = provider.createDefault() as? T {
                return defaultValue
            }
        }

        return nil
    }

    public func register(_ providing: AnyDefaultProviding) {
        providers.append(providing)
    }

    public func deregister(_ providing: AnyDefaultProviding) {
        providers.removeAll(where: { $0.defaultType == providing.defaultType })
    }
}
