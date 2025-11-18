//
//  MetatypeParser.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 24/07/25.
//

import Foundation

/// Represents a parsed type with optional generic arguments
public struct ParsedType: Hashable, Sendable {
    public let name: String
    public let genericArguments: [ParsedType]
}

public struct MetatypeParser {
    /// Parses a type and returns its structured representation
    public static func parse(_ type: Any.Type) -> ParsedType {
        return parseTypeName(String(describing: type))
    }

    /// Recursively parses a string description of a type
    private static func parseTypeName(_ name: String) -> ParsedType {
        // Handle generics
        if let genericStart = name.firstIndex(of: "<"),
           let genericEnd = name.lastIndex(of: ">"),
           genericStart < genericEnd {
            let baseName = String(name[..<genericStart])
            let genericsString = String(name[name.index(after: genericStart)..<genericEnd])
            let genericTypes = splitGenericArguments(genericsString).map { parseTypeName($0.trimmingCharacters(in: .whitespaces)) }
            return ParsedType(name: baseName, genericArguments: genericTypes)
        } else {
            // Non-generic type
            return ParsedType(name: name, genericArguments: [])
        }
    }

    /// Handles nested generic arguments properly
    private static func splitGenericArguments(_ input: String) -> [String] {
        var result: [String] = []
        var currentArgument = ""
        var bracketCount = 0
        var parenthesisCount = 0

        for char in input {
            if char == "<" {
                bracketCount += 1
            } else if char == ">" {
                bracketCount -= 1
            } else if char == "(" {
                parenthesisCount += 1
            } else if char == ")" {
                parenthesisCount -= 1
            }

            if char == "," && bracketCount == 0 && parenthesisCount == 0 {
                result.append(currentArgument.trimmingCharacters(in: .whitespaces))
                currentArgument = ""
            } else {
                currentArgument.append(char)
            }
        }

        if !currentArgument.isEmpty {
            result.append(currentArgument.trimmingCharacters(in: .whitespaces))
        }

        return result
    }
}
