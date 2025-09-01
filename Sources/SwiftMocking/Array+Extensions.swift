//
//  Array+Extensions.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 19/07/25.
//

extension Array {
    /// Transforms and returns the first successfully mapped element in the array.
    ///
    /// This method applies a transformation function to each element in the array
    /// and returns the first non-nil result. If no element can be successfully
    /// transformed, it returns nil.
    ///
    /// - Parameter f: A transformation function that takes an array element and returns
    ///   an optional transformed value. The function should return nil if the element
    ///   cannot be transformed.
    /// - Returns: The first successfully transformed element, or nil if no element
    ///   could be transformed.
    func firstMap<T>(_ f: (Element) -> T?) -> T? {
        for item in self {
            guard let transformed = f(item) else {
                continue
            }

            return transformed
        }

        return nil
    }
}
