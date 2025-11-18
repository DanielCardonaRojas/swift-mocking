//
//  MockableOptions.swift
//  Mockable
//
//  Created by Daniel Cardona on 9/07/25.
//

import Foundation

/// A set of options that control the code generation behavior of the `@Mockable` macro.
///
/// These options can be combined to customize how mock objects are generated.
///
/// ### Usage Example:
///
/// ```swift
/// @Mockable([.includeWitness, .suffixMock])
/// protocol MyService {
///     func fetchData() -> String
/// }
///
/// // This will generate a mock named MyServiceMock and include a Witness type.
/// ```
public struct MockableOptions: OptionSet {
    public let rawValue: Int
    nonisolated(unsafe) public static var `default`: MockableOptions = [.prefixMock]

    /// Suffixes the generated mock type name with "Mock" (e.g., `MyServiceMock`).
    nonisolated(unsafe) public static let suffixMock = MockableOptions(
        rawValue: 1 << 0
    )

    /// Prefixes the generated mock type name with "Mock" (e.g., `MockMyService`).
    nonisolated(unsafe) public static let prefixMock = MockableOptions(
        rawValue: 1 << 1
    )

    /// Initializes a `MockableOptions` instance with the given raw value.
    /// - Parameter rawValue: The raw integer value representing the option set.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Initializes a `MockableOptions` instance from a string literal.
    ///
    /// This initializer is used by the `@Mockable` macro to parse options provided as strings.
    /// Supported string values include "includeWitness", "suffixMock", "prefixMock", and "defaults".
    /// Options can be comma-separated (e.g., "includeWitness,suffixMock").
    /// - Parameter stringLiteral: The string representation of the options.
    public init?(stringLiteral: String) {
        var combinedOptions: MockableOptions = []
        let cleanedString = stringLiteral.replacingOccurrences(of: #"[\[\]. ]"#, with: "", options: .regularExpression)
        let components = cleanedString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        for component in components {
            switch component {
            case "suffixMock":
                combinedOptions.formUnion(.suffixMock)
            case "prefixMock":
                combinedOptions.formUnion(.prefixMock)
            case "": // Handle empty string if there are trailing commas or empty array
                continue
            default:
                // If any component is unrecognized, the whole initialization fails
                return nil
            }
        }
        self = combinedOptions
    }

    /// Returns an array of string identifiers for the options currently set.
    public var identifiers: [String] {
        var names: [String] = []
        if contains(.prefixMock) { names.append("prefixMock") }
        if contains(.suffixMock) { names.append("suffixMock") }
        return names
    }
}
