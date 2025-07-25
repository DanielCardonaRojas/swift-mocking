//
//  MetatypeParser.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 24/07/25.
//

import Foundation

/// Represents a parsed type with optional generic arguments
public struct ParsedType: Hashable {
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
        var current = ""
        var depth = 0

        for char in input {
            if char == "<" {
                depth += 1
                current.append(char)
            } else if char == ">" {
                depth -= 1
                current.append(char)
            } else if char == "," && depth == 0 {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            result.append(current)
        }

        return result
    }
}
