
//
//  DefaultProvidable.swift
//  MockableTypes
//
//  Created by Daniel Cardona on 11/07/25.
//

import Foundation

/// A type that can provide a default value.
///
/// Conforming to this protocol allows a type to be used in mocks where a default value is needed for unstubbed methods.
public protocol DefaultProvidable {
    /// The default value for the conforming type.
    static var defaultValue: Self { get }
}

// MARK: - Default Implementations

extension Optional: DefaultProvidable {
    public static var defaultValue: Self {
        return nil
    }
}

extension String: DefaultProvidable {
    public static var defaultValue: String {
        return ""
    }
}

extension Int: DefaultProvidable {
    public static var defaultValue: Int {
        return 0
    }
}

extension Double: DefaultProvidable {
    public static var defaultValue: Double {
        return 0.0
    }
}

extension Float: DefaultProvidable {
    public static var defaultValue: Float {
        return 0.0
    }
}

extension Bool: DefaultProvidable {
    public static var defaultValue: Bool {
        return false
    }
}

extension Array: DefaultProvidable {
    public static var defaultValue: [Element] {
        return []
    }
}

extension Dictionary: DefaultProvidable {
    public static var defaultValue: Self {
        return [:]
    }
}

extension Set: DefaultProvidable {
    public static var defaultValue: Set<Element> {
        return []
    }
}
