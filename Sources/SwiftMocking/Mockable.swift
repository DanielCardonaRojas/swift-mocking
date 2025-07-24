//
//  Mockable.swift
//  Mockable
//
//  Created by Daniel Cardona on 5/07/25.
//

import Foundation
import SwiftMockingOptions

@attached(peer, names: suffixed(Mock), prefixed(Mock), suffixed(Witness))
public macro Mockable(_ options: MockableOptions = .default) = #externalMacro(module: "SwiftMockingMacros", type: "MockableMacro")
