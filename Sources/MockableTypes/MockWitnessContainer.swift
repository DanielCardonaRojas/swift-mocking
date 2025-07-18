//
//  MockWitnessContainer.swift
//  swift-mocking
//
//  Created by Daniel Cardona on 17/07/25.
//

import WitnessTypes

public typealias Mocking = Mock & MockWitnessContainer

/// Base protocol for all mocks
public protocol MockWitnessContainer<Witness> {
    associatedtype Witness: RecordableMixin
    var witness: Witness { get }
    init()
}

public extension MockWitnessContainer {
    func setup() {
        witness.register(strategy: "mocking")
        witness.register(strategy: "static")
    }
    static func setup() {
        Self.init().setup()
    }
}
