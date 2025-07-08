//
//  Invocation.swift
//  Mockable
//
//  Created by Daniel Cardona on 8/07/25.
//

public struct Invocation<each Input> {
    let arguments: (repeat each Input)

    init(arguments: repeat each Input) {
        self.arguments = (repeat each arguments)
    }
}

