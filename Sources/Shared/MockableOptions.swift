//
//  MockableOptions.swift
//  Mockable
//
//  Created by Daniel Cardona on 9/07/25.
//

public struct MockableOptions: OptionSet {
    public let rawValue: Int
    public static let includeWitness = MockableOptions(rawValue: 1 << 0)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init?(stringLiteral: String) {
        var combinedOptions: MockableOptions = []
        let cleanedString = stringLiteral.replacingOccurrences(of: #"[\[\]. ]"#, with: "", options: .regularExpression)
        let components = cleanedString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        for component in components {
            switch component {
            case "includeWitness":
                combinedOptions.formUnion(.includeWitness)
            case "": // Handle empty string if there are trailing commas or empty array
                continue
            default:
                // If any component is unrecognized, the whole initialization fails
                return nil
            }
        }
        self = combinedOptions
    }

    public var identifiers: [String] {
        var names: [String] = []
        if contains(.includeWitness) { names.append("includeWitness") }
        return names
    }
}
