//
//  Array+Extensions.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 19/07/25.
//

extension Array {
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
