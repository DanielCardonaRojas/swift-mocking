//
//  Mockable.swift
//  Mockable
//
//  Created by Daniel Cardona on 5/07/25.
//

import Foundation
@_exported import MockableTypes

@attached(peer, names: suffixed(Mock), prefixed(Mock), suffixed(Witness))
public macro Mockable(_ options: MockableOptions = []) = #externalMacro(module: "SwiftMockingMacros", type: "MockableMacro")
