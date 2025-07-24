//
//  Mockable.swift
//  Mockable
//
//  Created by Daniel Cardona on 5/07/25.
//

import Foundation

@attached(peer, names: suffixed(Mock), prefixed(Mock), suffixed(Witness))
public macro Mockable() = #externalMacro(module: "SwiftMockingMacros", type: "MockableMacro")
