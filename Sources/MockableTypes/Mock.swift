//
//  Mock.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 13/07/25.
//

@dynamicMemberLookup
open class Mock {
    public init() { }
    private(set) var spies: [String: AnySpy] = [:]

    public subscript<each Input, Eff: Effect, Output>(dynamicMember member: String) -> Spy<repeat each Input, Eff, Output> {
        if let existingSpy = spies[member] as? Spy<repeat each Input, Eff, Output> {
            return existingSpy
        } else {
            let spy = Spy<repeat each Input, Eff, Output>()
            spies[member] = spy
            return spy
        }
    }

    public func clear() {
        spies.values.forEach { $0.clear() }
    }
}

